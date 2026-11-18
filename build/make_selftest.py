import re, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
html = open(f"{ROOT}/powerbi/customer_churn_dashboard.html", encoding='utf-8').read()

harness = """
<script>
window.__errs = [];
window.addEventListener('error', function(e){ window.__errs.push(String(e.message)); });
setTimeout(function(){
  var out = {};
  function kpis(){ return [].slice.call(document.querySelectorAll('#kpis1 .kpi .v')).map(function(e){return e.textContent.trim();}); }
  function txt(id){ var e = document.getElementById(id); return e ? e.textContent.replace(/\\s+/g,' ').trim().slice(0,220) : 'MISSING'; }
  function svgs(){ return document.querySelectorAll('.page.active svg').length; }

  out.p1 = {kpis: kpis(), svgs: svgs(), note: txt('fltNote'),
            tenure: txt('t-tenure1'), contract: txt('t-contract1'),
            segment: txt('t-segment1'), service: txt('t-service1'),
            pill: document.getElementById('verifyPill').textContent};

  showPage(2);
  out.p2 = {svgs: svgs(), drivers: txt('t-drivers'), payment: txt('t-payment2'),
            support: txt('t-support2'), addons: txt('t-addons2')};

  showPage(3);
  out.p3 = {svgs: svgs(), rule: txt('t-rule'), tiers: txt('t-tiers'),
            pareto: txt('t-pareto'), composition: txt('t-composition'), rev: txt('t-tierrev'),
            tableRows: document.querySelectorAll('#tierTable tbody tr').length,
            tierCards: document.querySelectorAll('#tiers .tier').length};

  var s = document.getElementById('f-contract');
  s.value = '0'; s.dispatchEvent(new Event('change'));
  out.filtered = {kpis: kpis(), note: txt('fltNote'), rule: txt('t-rule')};

  var s2 = document.getElementById('f-tenure');
  s2.value = '0'; s2.dispatchEvent(new Event('change'));
  out.filtered2 = {kpis: kpis(), note: txt('fltNote')};

  document.getElementById('reset').click();
  out.reset = {kpis: kpis(), note: txt('fltNote')};

  out.errs = window.__errs;
  out.overflow = [].slice.call(document.querySelectorAll('.card,.kpi,.tier'))
                   .filter(function(e){ return e.scrollWidth > e.clientWidth + 2; }).length;
  document.title = 'RESULT::' + JSON.stringify(out);
}, 700);
</script>
</body>"""
open(f"{ROOT}/build/dash_selftest.html", 'w', encoding='utf-8').write(html.replace("</body>", harness, 1))
print("harness size KB:", round(os.path.getsize(f'{ROOT}/build/dash_selftest.html')/1024, 1))
