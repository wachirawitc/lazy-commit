#!/usr/bin/env bash
# Helper for the lazy-commit skill: the deterministic git steps of the workflow.
#
#   bash lazy-commit.sh init [<path>]
#   bash lazy-commit.sh stage  [--skip-graphify] [--secret <glob>]... [--full]
#   bash lazy-commit.sh plan   [--skip-graphify] [--max-header <n>] [--unit <dir>/]... [--commit] < plan
#   bash lazy-commit.sh commit [--skip-graphify]
#
# Output starting with "stop:" means the workflow must stop; "error:" lines mean the plan must be
# fixed; "changed:", "mismatch:" and "rejected:" are commit outcomes described in SKILL.md.
# Runs from anywhere inside the repository. Works with bash 3.2+ (macOS) and Git Bash on Windows.

set -u
export LC_ALL=C

out() { printf '%s\n' "$@"; }
stop() { out "stop: $1"; exit "${2:-2}"; }

self=${0//\\//}
SKILL_DIR=$(cd "$(dirname "$self")/.." && pwd) || exit 1

TOP=$(git rev-parse --show-toplevel 2>/dev/null) || stop "Not inside a git repository."
cd "$TOP" || exit 1

TMP=$(mktemp -d "${TMPDIR:-/tmp}/lazy-commit.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
PLAN_DIR=$(git rev-parse --git-path lazy-commit)

g() { git -c core.quotePath=false -c core.safecrlf=false -c color.ui=false "$@"; }

cmd=${1:-}
[ $# -gt 0 ] && shift
SKIP=0 FULL=0 MAXH=100 AND_COMMIT=0 INIT_PATH=""
: > "$TMP/secrets"
: > "$TMP/units"
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-graphify) SKIP=1 ;;
    --full) FULL=1 ;;
    --commit) AND_COMMIT=1 ;;
    --secret|--unit|--max-header)
      [ $# -ge 2 ] || { out "error: $1 needs a value"; exit 1; }
      case "$1" in
        --secret) printf '%s\n' "$2" >> "$TMP/secrets" ;;
        --unit) printf '%s\n' "$2" >> "$TMP/units" ;;
        --max-header) MAXH=$2 ;;
      esac
      shift ;;
    *)
      if [ "$cmd" = init ] && [ -z "$INIT_PATH" ]; then INIT_PATH=$1
      else out "error: unknown option $1"; exit 1; fi ;;
  esac
  shift
done

# --- shared steps -------------------------------------------------------------------------------

# Stage all: every change, or everything except graphify-out/ with --skip-graphify.
stage_all() {
  if [ "$SKIP" = 1 ]; then
    git reset -q >/dev/null 2>&1
    g add -A -- . ':!graphify-out' > "$TMP/add.err" 2>&1
  else
    g add -A > "$TMP/add.err" 2>&1
  fi || { out "stop: git add failed:"; cat "$TMP/add.err"; exit 2; }
}

graphify_pending() { [ -n "$(git status --porcelain -- graphify-out 2>/dev/null)" ]; }

# Refuse states where committing would be wrong: no branch, the default branch, or an unfinished
# merge/rebase/cherry-pick/revert (staging everything would mark conflicts resolved, and the plain
# `git reset` used between commits would silently drop the merge).
check_state() {
  BRANCH=$(git branch --show-current 2>/dev/null)
  [ -n "$BRANCH" ] || stop "Not on a branch (detached HEAD). Check out a branch, then run /lazy-commit again."
  case "$BRANCH" in
    main|master) stop "Committing to the default branch ($BRANCH) is not allowed." ;;
  esac
  local p
  p=$(git rev-parse --git-path MERGE_HEAD)
  [ -e "$p" ] && stop "A merge is in progress. Finish it with git commit (or git merge --abort), then run /lazy-commit again."
  p=$(git rev-parse --git-path CHERRY_PICK_HEAD)
  [ -e "$p" ] && stop "A cherry-pick is in progress. Finish it with git cherry-pick --continue (or --abort), then run /lazy-commit again."
  p=$(git rev-parse --git-path REVERT_HEAD)
  [ -e "$p" ] && stop "A revert is in progress. Finish it with git revert --continue (or --abort), then run /lazy-commit again."
  for p in rebase-merge rebase-apply; do
    p=$(git rev-parse --git-path "$p")
    [ -e "$p" ] && stop "A rebase (or git am) is in progress. Finish or abort it, then run /lazy-commit again."
  done
  [ -n "$(git ls-files -u | head -n 1)" ] && stop "Some files have unresolved merge conflicts. Resolve them, then run /lazy-commit again."
  return 0
}

# Paths on stdin that look like secrets: the built-in patterns plus each --secret glob, by name only.
secret_hits() {
  local p q base glob hit
  shopt -s nocasematch
  while IFS= read -r p; do
    q=$p
    case "$q" in \"*\") q=${q#\"}; q=${q%\"} ;; esac
    base=${q##*/}
    hit=0
    case "$base" in
      .env.example) ;;
      .env|.env.*|*.pfx|*.p12|*.key|*.pem) hit=1 ;;
    esac
    if [ "$hit" = 0 ]; then
      while IFS= read -r glob; do
        glob=${glob#./}; glob=${glob#/}
        [ -n "$glob" ] || continue
        case "$q" in $glob) hit=1; break ;; esac
        case "$base" in $glob|${glob#\*\*/}) hit=1; break ;; esac
      done < "$TMP/secrets"
    fi
    [ "$hit" = 1 ] && printf '%s\n' "$p"
  done
  shopt -u nocasematch
}

# The staged list as "<status>\t<+added -deleted | binary>\t<path>", or summarized by folder when
# there are more than 300 paths (unless --full).
print_staged() {
  local n
  g diff --cached --name-status --no-renames > "$TMP/ns"
  g diff --cached --numstat --no-renames > "$TMP/num"
  n=$(wc -l < "$TMP/ns" | tr -d ' ')
  if [ "$n" -gt 300 ] && [ "$FULL" = 0 ]; then
    out "--- staged: $n files, summarized by folder (stage --full lists every path)"
    awk -F'\t' '
      { s = $1; p = $2; n = split(p, seg, "/")
        if (n >= 3) u = seg[1] "/" seg[2] "/"; else if (n == 2) u = seg[1] "/"; else u = p
        if (!(u in cnt)) { order[++k] = u; first[u] = s "\t" p }
        cnt[u]++; sc[u, s]++ }
      END { split("A M D T U X C R", L, " ")
        for (i = 1; i <= k; i++) { u = order[i]
          if (cnt[u] == 1) { print first[u]; continue }
          line = u "** (" cnt[u] " files:"; sep = " "
          for (j = 1; j <= 8; j++) if ((u, L[j]) in sc) { line = line sep sc[u, L[j]] " " L[j]; sep = ", " }
          print line ")" } }' "$TMP/ns"
  else
    if [ "$n" = 1 ]; then out "--- staged: 1 file (status, line counts, path)"; else out "--- staged: $n files (status, line counts, path)"; fi
    awk -F'\t' '
      FILENAME == ARGV[1] { c[$3] = ($1 == "-") ? "binary" : "+" $1 " -" $2; next }
      { printf "%s\t%s\t%s\n", $1, (($2 in c) ? c[$2] : "?"), $2 }' "$TMP/num" "$TMP/ns"
  fi
}

made_so_far() {
  out "--- commits made so far"
  if [ "$1" -gt 0 ]; then git log -"$1" --oneline; else out "None"; fi
}

# --- commands -----------------------------------------------------------------------------------

cmd_init() {
  local target=".agents/rules/git/commit-config.md" a ok=1
  if [ -n "$INIT_PATH" ]; then
    a=${INIT_PATH#@}
    case "$a" in \"*\") a=${a#\"}; a=${a%\"} ;; \'*\') a=${a#\'}; a=${a%\'} ;; esac
    a=${a//\\//}
    a=${a#./}
    shopt -s nocasematch
    [[ "$a" == "$target" || "$a" == "$TOP/$target" ]] || ok=0
    shopt -u nocasematch
    [ "$ok" = 1 ] || stop "lazy-commit reads its config only from .agents/rules/git/commit-config.md."
  fi
  [ -e "$target" ] && stop ".agents/rules/git/commit-config.md already exists; it was left unchanged."
  mkdir -p .agents/rules/git && cp "$SKILL_DIR/templates/commit-config.md" "$target" \
    || stop "Could not create .agents/rules/git/commit-config.md."
  out "Created .agents/rules/git/commit-config.md. Fill in the sections you need; a section left as its comment keeps the default."
}

cmd_stage() {
  check_state
  rm -rf "$PLAN_DIR" "$PLAN_DIR.new"
  [ -n "$(git status --porcelain)" ] || stop "Nothing to commit."
  stage_all
  if [ -z "$(g diff --cached --name-only)" ]; then
    if [ "$SKIP" = 1 ] && graphify_pending; then stop "Nothing to commit. graphify-out/ changes are left uncommitted."; fi
    stop "Nothing to commit."
  fi
  g diff --cached --name-only --no-renames | secret_hits > "$TMP/hits"
  if [ -s "$TMP/hits" ]; then
    git reset -q
    out "stop: These staged paths look like secrets, so nothing was committed and all changes were unstaged:"
    sed 's/^/  /' "$TMP/hits"
    exit 3
  fi
  out "branch: $BRANCH"
  if [ "$SKIP" = 1 ] && graphify_pending; then out "note: graphify-out/ changes are left uncommitted (--skip-graphify)."; fi
  print_staged
  out "--- last commits"
  git log -10 --oneline 2>/dev/null || out "(no commits yet)"
}

cmd_plan() {
  case "$MAXH" in ''|*[!0-9]*) out "error: --max-header needs a number"; exit 1 ;; esac
  tr -d '\r' > "$TMP/plan"
  g diff --cached --name-status --no-renames > "$TMP/ns"
  [ -s "$TMP/ns" ] || stop "Nothing is staged. Run stage first."
  rm -rf "$PLAN_DIR.new"
  mkdir -p "$PLAN_DIR.new" || exit 1
  awk -F'\t' -v maxh="$MAXH" -v outdir="$PLAN_DIR.new" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function err(m) { errs[++nerr] = m }
    function strip_quote(s) { return (substr(s, 1, 1) == "\"") ? substr(s, 2) : s }
    function unit_of(path,    cmp, best, bl, x, uu, rest, pos) {
      cmp = strip_quote(path); best = ""; bl = 0
      for (x = 1; x <= nu; x++) {
        uu = units[x]; if (uu == "") continue
        if (substr(uu, length(uu)) != "/") uu = uu "/"
        if (substr(cmp, 1, length(uu)) == uu && length(uu) > bl) { best = uu; bl = length(uu) }
      }
      rest = substr(cmp, bl + 1); pos = index(rest, "/")
      return (pos == 0) ? "" : best substr(rest, 1, pos)
    }
    FILENAME == ARGV[1] { units[++nu] = trim($0); next }
    FILENAME == ARGV[2] { np++; st[np] = $1; ps[np] = $2; next }
    {
      line = $0
      if (line ~ /^=== /) { k++; hdr[k] = trim(substr(line, 5)); nb[k] = 0; state = 1; next }
      if (state == 1 && trim(line) == "--- files") { state = 2; next }
      if (state == 0) { if (trim(line) != "") err("text before the first \"=== <header>\" line: " line); next }
      if (state == 1) { body[k, ++nb[k]] = line; next }
      e = line
      if (index(e, "\t")) sub(/^.*\t/, "", e)
      e = trim(e)
      if (e == "") next
      if (e ~ /\/\*\*$/) e = substr(e, 1, length(e) - 2)
      if (e in seen) {
        if (seen[e] == k) err("\"" e "\" is listed twice in commit " k)
        else err("\"" e "\" is listed in commit " seen[e] " and commit " k)
        next
      }
      seen[e] = k; ne++; ent[ne] = e; entc[ne] = k
    }
    END {
      if (k == 0) err("the plan has no commits; start each commit with a \"=== <header>\" line")
      for (i = 1; i <= k; i++) {
        h = hdr[i]
        if (h == "") err("commit " i " has no header")
        else if (length(h) > maxh + 0) err("commit " i " header is " length(h) " characters, over the " maxh "-character limit: " h)
        f = 1; l = nb[i]
        while (f <= l && trim(body[i, f]) == "") f++
        while (l >= f && trim(body[i, l]) == "") l--
        bf[i] = f; bl[i] = l
        for (j = f; j <= l; j++) {
          b = body[i, j]
          if (b ~ /^[A-Za-z][A-Za-z-]*-[Bb][Yy]:/ || b ~ /^[^A-Za-z0-9]*Generated (with|by) /)
            err("commit " i " has a trailer or attribution line: " b)
        }
      }
      for (p = 1; p <= np; p++) {
        path = ps[p]; cmp = strip_quote(path); best = 0; bs = -1
        for (x = 1; x <= ne; x++) {
          e = ent[x]
          if (e == path) sc = 1000000 + length(e)
          else if (substr(e, length(e)) == "/" && substr(cmp, 1, length(e)) == e) sc = length(e)
          else continue
          if (sc > bs) { bs = sc; best = x }
        }
        if (best == 0) { err("not in any commit: " path); continue }
        used[best] = 1; c = entc[best]; cnt[c]++; cp[c, cnt[c]] = p
      }
      for (x = 1; x <= ne; x++) if (!(x in used)) err("\"" ent[x] "\" (commit " entc[x] ") matches no staged path")
      for (i = 1; i <= k; i++) if (hdr[i] != "" && cnt[i] + 0 == 0) err("commit " i " has no files")
      if (nerr > 0) { for (i = 1; i <= nerr; i++) print "error: " errs[i]; exit 4 }

      print k > (outdir "/n"); close(outdir "/n")
      for (i = 1; i <= k; i++) {
        f = outdir "/" i ".msg"
        print hdr[i] > f
        if (bl[i] >= bf[i]) {
          print "" > f; hasbody = 1
          for (j = bf[i]; j <= bl[i]; j++) { b = body[i, j]; sub(/[ \t]+$/, "", b); print b > f }
        }
        close(f)
        f = outdir "/" i ".paths"
        for (j = 1; j <= cnt[i]; j++) print ps[cp[i, j]] > f
        close(f)
      }
      if (hasbody) { print 1 > (outdir "/body"); close(outdir "/body") }

      printf "Proposed commits (%d):\n", k
      for (i = 1; i <= k; i++) {
        printf "\n%d. %s\n", i, hdr[i]
        for (j = bf[i]; j <= bl[i]; j++) { b = body[i, j]; sub(/[ \t]+$/, "", b); print ((b == "") ? "" : "   " b) }
        printf "   Files (%d):\n", cnt[i]
        if (cnt[i] <= 20) {
          for (j = 1; j <= cnt[i]; j++) { p = cp[i, j]; printf "   %s  %s\n", st[p], ps[p] }
          continue
        }
        nk = 0; split("", kc); split("", ko); split("", kst); split("", kfirst)
        for (j = 1; j <= cnt[i]; j++) {
          p = cp[i, j]; u = unit_of(ps[p]); key = (u == "") ? "\001" ps[p] : u
          if (!(key in kc)) { ko[++nk] = key; kfirst[key] = p }
          kc[key]++; kst[key, st[p]]++
        }
        split("A M D T U X C R", L, " ")
        for (x = 1; x <= nk; x++) {
          key = ko[x]
          if (kc[key] == 1) { p = kfirst[key]; printf "   %s  %s\n", st[p], ps[p]; continue }
          line = "   " key "** (" kc[key] " files:"; sep = " "
          for (y = 1; y <= 8; y++) if ((key, L[y]) in kst) { line = line sep kst[key, L[y]] " " L[y]; sep = ", " }
          print line ")"
        }
      }
    }' "$TMP/units" "$TMP/ns" "$TMP/plan" > "$TMP/proposal"
  local rc=$?
  if [ "$rc" != 0 ]; then
    rm -rf "$PLAN_DIR.new"
    cat "$TMP/proposal"
    exit 4
  fi
  cp "$TMP/ns" "$PLAN_DIR.new/staged"
  git branch --show-current > "$PLAN_DIR.new/branch"
  rm -rf "$PLAN_DIR"
  mv "$PLAN_DIR.new" "$PLAN_DIR" || exit 1
  if [ "$AND_COMMIT" = 1 ]; then cmd_commit; else cat "$TMP/proposal"; fi
}

cmd_commit() {
  [ -f "$PLAN_DIR/n" ] || stop "No saved plan. Run stage and plan first."
  check_state
  local planned n i made
  planned=$(cat "$PLAN_DIR/branch")
  [ "$planned" = "$BRANCH" ] || stop "The branch changed from $planned to $BRANCH since the proposal; nothing was committed."
  stage_all
  g diff --cached --name-status --no-renames > "$TMP/now"
  if ! cmp -s "$TMP/now" "$PLAN_DIR/staged"; then
    out "changed: the changes differ from the proposal, so nothing was committed. Differences:"
    awk -F'\t' '
      FILENAME == ARGV[1] { old[$0] = 1; next }
      { now[$0] = 1; if (!($0 in old)) printf "  now:  %s  %s\n", $1, $2 }
      END { for (l in old) if (!(l in now)) { split(l, a, "\t"); printf "  gone: %s  %s\n", a[1], a[2] } }' \
      "$PLAN_DIR/staged" "$TMP/now"
    print_staged
    rm -rf "$PLAN_DIR"
    exit 5
  fi
  n=$(cat "$PLAN_DIR/n"); i=1; made=0
  while [ "$i" -le "$n" ]; do
    git reset -q
    if ! g --literal-pathspecs add -A --pathspec-from-file="$PLAN_DIR/$i.paths" > "$TMP/add.err" 2>&1; then
      stage_all
      out "mismatch: commit $i/$n could not be staged, so it was not committed:"
      cat "$TMP/add.err"
      made_so_far "$made"; rm -rf "$PLAN_DIR"; exit 6
    fi
    g diff --cached --name-only --no-renames | sort > "$TMP/got"
    sort "$PLAN_DIR/$i.paths" > "$TMP/want"
    if ! cmp -s "$TMP/got" "$TMP/want"; then
      stage_all
      out "mismatch: commit $i/$n staged different paths than planned, so it was not committed:"
      diff "$TMP/want" "$TMP/got" | sed -n 's/^< /  missing: /p; s/^> /  extra:   /p'
      made_so_far "$made"; rm -rf "$PLAN_DIR"; exit 6
    fi
    if ! git commit -q --cleanup=verbatim -F "$PLAN_DIR/$i.msg" > "$TMP/commit.out" 2>&1; then
      stage_all
      out "rejected: commit $i/$n was rejected: $(head -n 1 "$PLAN_DIR/$i.msg")"
      made_so_far "$made"
      out "--- hook output"
      cat "$TMP/commit.out"
      rm -rf "$PLAN_DIR"; exit 7
    fi
    made=$((made + 1)); i=$((i + 1))
  done
  stage_all
  if [ -f "$PLAN_DIR/body" ]; then git log -"$made" --format='%h %B'; else git log -"$made" --oneline; fi
  rm -rf "$PLAN_DIR"
  if [ "$SKIP" = 1 ] && graphify_pending; then out "graphify-out/ changes are left uncommitted."; fi
  if [ "$SKIP" = 1 ]; then g status --porcelain -- . ':!graphify-out' > "$TMP/left"; else g status --porcelain > "$TMP/left"; fi
  if [ -s "$TMP/left" ]; then out "Left uncommitted:"; sed 's/^/  /' "$TMP/left"; fi
  return 0
}

case "$cmd" in
  init) cmd_init ;;
  stage) cmd_stage ;;
  plan) cmd_plan ;;
  commit) cmd_commit ;;
  *) out "usage: lazy-commit.sh init|stage|plan|commit [options]"; exit 1 ;;
esac
