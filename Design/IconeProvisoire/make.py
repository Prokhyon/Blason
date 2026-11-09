import sys
def svg(bg1, bg2, paper, ink, rule, die1, die2, pip, shadow):
    rows = ""
    for i, y in enumerate([340, 410, 480, 550, 620]):
        w = [190, 150, 210, 170, 130][i]
        rows += f'<rect x="290" y="{y+11}" width="{w}" height="18" rx="9" fill="{rule}"/>'
        rows += f'<rect x="540" y="{y}" width="86" height="42" rx="11" fill="none" stroke="{ink}" stroke-width="7"/>'
    pips = "".join(f'<circle cx="{x}" cy="{y}" r="27" fill="{pip}"/>' for x, y in
                   [(615, 615), (775, 615), (695, 695), (615, 775), (775, 775)])
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
 <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{bg1}"/><stop offset="1" stop-color="{bg2}"/></linearGradient>
 <linearGradient id="die" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{die1}"/><stop offset="1" stop-color="{die2}"/></linearGradient>
 <filter id="sh" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#000" flood-opacity="{shadow}"/></filter>
</defs>
<rect width="1024" height="1024" fill="url(#bg)"/>
<g transform="translate(-20 -30) rotate(-6 460 470)" filter="url(#sh)">
 <rect x="240" y="180" width="430" height="580" rx="38" fill="{paper}"/>
 <rect x="290" y="240" width="230" height="36" rx="18" fill="{ink}"/>
 {rows}
</g>
<g transform="translate(-20 -30) rotate(14 695 695)" filter="url(#sh)">
 <rect x="550" y="550" width="290" height="290" rx="62" fill="url(#die)"/>
 {pips}
</g>
</svg>'''
variants = {
 "light": svg("#4657B0", "#232F73", "#FBF8F1", "#2F3C8C", "#C9CCDB", "#EE5A5F", "#B8262B", "#FFFFFF", 0.35),
 "dark":  svg("#1A2150", "#0B0F27", "#ECE8DE", "#2F3C8C", "#BFC2D1", "#E5484D", "#A61F24", "#FFFFFF", 0.5),
 "tinted": svg("#000000", "#000000", "#F2F2F2", "#5A5A5A", "#A8A8A8", "#C8C8C8", "#8A8A8A", "#202020", 0.5),
}
out = sys.argv[1]
for name, text in variants.items():
    open(f"{out}/icon-{name}.svg", "w").write(text)
