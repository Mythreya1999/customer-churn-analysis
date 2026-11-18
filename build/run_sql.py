"""Execute the governed SQL layer against SQLite and render every result set to markdown.

Reports per-file statements_ok / errors, adjudicates every integrity-gate row, and
fails loudly if any gate row is not PASS or any statement errors.
"""
import sqlite3, pandas as pd, os, re, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB   = f"{ROOT}/db/churn.db"
RAW  = f"{ROOT}/data/raw/customer_churn.csv"
SQLD = f"{ROOT}/sql"
OUTD = f"{ROOT}/reports/sql"
FILES = ['01_data_exploration.sql', '02_churn_analysis.sql',
         '03_customer_segmentation.sql', '04_retention_insights.sql']
os.makedirs(OUTD, exist_ok=True)


def split_statements(sql):
    """Split on ';' that are not inside single-quoted strings or -- line comments."""
    stmts, buf, in_str, i = [], [], False, 0
    while i < len(sql):
        ch = sql[i]
        if not in_str and sql[i:i+2] == '--':
            j = sql.find('\n', i)
            j = len(sql) if j == -1 else j
            buf.append(sql[i:j]); i = j; continue
        if ch == "'":
            in_str = not in_str
        if ch == ';' and not in_str:
            stmts.append(''.join(buf)); buf = []
        else:
            buf.append(ch)
        i += 1
    if ''.join(buf).strip():
        stmts.append(''.join(buf))
    return stmts


def leading_comment(stmt):
    """The -- comment paragraph directly above the statement (stops at a blank line)."""
    comments = []
    for line in stmt.split('\n'):
        s = line.strip()
        if s.startswith('--'):
            c = s.lstrip('-').strip()
            if c and not set(c) <= {'-', '='}:
                comments.append(c)
        elif not s:
            if comments:
                break
        else:
            break
    return ' '.join(comments)[:300]


def fmt(res):
    """Render floats as plain decimals - 1.3e+06 in a deliverable reads as an error."""
    res = res.copy()
    for c in res.columns:
        if res[c].dtype.kind == 'f':
            res[c] = res[c].map(lambda v: '' if pd.isna(v) else f"{v:,.2f}")
    return res


os.makedirs(os.path.dirname(DB), exist_ok=True)   # db/ is gitignored, so it may not exist on a fresh clone
if os.path.exists(DB):
    os.remove(DB)
con = sqlite3.connect(DB)
pd.read_csv(RAW).to_sql('customer_churn', con, index=False)

summary, gate_fail = [], []

for fname in FILES:
    sql = open(f"{SQLD}/{fname}", encoding='utf-8').read()
    stmts = [s for s in split_statements(sql) if s.strip()]
    ok = errs = 0
    parts = [f"# {fname}\n"]
    last_title = ''
    for st in stmts:
        title = leading_comment(st) or last_title     # trailing SELECT inherits its BQ heading
        code = re.sub(r'^\s*--.*$', '', st, flags=re.M).strip().rstrip(';').strip()
        if not code:
            continue
        if title:
            last_title = title
        cur = con.cursor()
        try:
            cur.execute(code)
            if cur.description is None:                # DDL / view creation
                ok += 1
                con.commit()
                continue
            res = pd.DataFrame(cur.fetchall(), columns=[d[0] for d in cur.description])
            ok += 1
            if res.empty:
                continue
            parts.append(f"\n## {title}\n" if title else f"\n## Query {ok}\n")
            parts.append(fmt(res).to_markdown(index=False) + "\n")
            if 'check_name' in res.columns:
                for _, r in res.iterrows():
                    a, e = str(r['actual']).strip(), str(r['expected']).strip()
                    match = (a == e) or (a.replace(',', '') == e.replace(',', ''))
                    if not match:
                        try:
                            match = abs(float(a.replace(',', '')) - float(e.replace(',', ''))) < 1e-6
                        except Exception:
                            match = False
                    status = 'PASS' if match else 'FAIL'
                    parts.append(f"- `{r['check_name']}`: actual=`{a}` expected=`{e}` -> **{status}**\n")
                    if not match:
                        gate_fail.append((fname, r['check_name'], a, e))
        except Exception as ex:
            errs += 1
            parts.append(f"\n**ERROR** in statement starting `{code[:90]}`\n\n```\n{ex}\n```\n")
    open(f"{OUTD}/{fname.replace('.sql', '.md')}", 'w', encoding='utf-8').write('\n'.join(parts))
    executed = len([s for s in stmts if re.sub(r'^\s*--.*$', '', s, flags=re.M).strip()])
    summary.append({'file': fname, 'statements': executed, 'statements_ok': ok, 'errors': errs})

print(pd.DataFrame(summary).to_string(index=False))
print("\nTOTAL: %d statements, %d ok, %d errors"
      % (sum(s['statements'] for s in summary), sum(s['statements_ok'] for s in summary),
         sum(s['errors'] for s in summary)))
print("GATE:", "ALL PASS" if not gate_fail else f"{len(gate_fail)} FAILURES")
for g in gate_fail:
    print("   ", g)
con.close()
json.dump({'summary': summary, 'gate_failures': gate_fail},
          open(f"{ROOT}/reports/sql/_run_summary.json", 'w'), indent=2)
sys.exit(1 if gate_fail or any(s['errors'] for s in summary) else 0)
