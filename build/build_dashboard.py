import json, os, shutil, subprocess, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tpl = open(f"{ROOT}/build/churn_dashboard_template.html", encoding='utf-8').read()
payload = open(f"{ROOT}/build/dash_payload.json", encoding='utf-8').read()
out = tpl.replace("/*__PAYLOAD__*/", payload)
assert "/*__PAYLOAD__*/" not in out, "payload marker not replaced"
path = f"{ROOT}/powerbi/customer_churn_dashboard.html"
open(path, 'w', encoding='utf-8').write(out)
print("written", path, round(os.path.getsize(path)/1024, 1), "KB")

# syntax-check the embedded script with node, so a parse error cannot ship silently.
# Node is optional: the dashboard itself has no runtime dependency on it.
if shutil.which('node'):
    script = max(re.findall(r'<script>(.*?)</script>', out, re.S), key=len)
    js = f"{ROOT}/build/_check.js"
    open(js, 'w', encoding='utf-8').write(script)
    r = subprocess.run(['node', '--check', js], capture_output=True, text=True)
    print("JS syntax:", "OK" if r.returncode == 0 else "FAIL")
    if r.returncode != 0:
        print(r.stderr[:800])
    os.remove(js)
else:
    print("JS syntax: SKIPPED (node not installed)")
