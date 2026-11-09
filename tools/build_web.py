#!/usr/bin/env python3
"""Builds App/Web/index.html from the approved prototype (wird.html) for the iPhone app.
Usage: python3 tools/build_web.py path/to/wird.html
"""
import re, sys, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
src = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')

def rep(a, b, count=1):
    global src
    n = src.count(a)
    if n != count:
        sys.exit(f'build_web: expected {count} of {a[:60]!r}, found {n}')
    src = src.replace(a, b)

# offline fonts instead of Google Fonts
src = re.sub(r'<link rel="preconnect"[^>]*>\s*', '', src)
src, n = re.subn(r'<link rel="stylesheet" href="https://fonts\.googleapis\.com[^"]*">', '<link rel="stylesheet" href="fonts.css">', src)
if n != 1: sys.exit('build_web: google fonts link not found')
# make these overridable by the native bridge
rep("const saveS = () => ls.set('settings', S);", "function saveS(){ ls.set('settings', S) }")
rep("const saveIst = () => ls.set('ist', IST);", "function saveIst(){ ls.set('ist', IST) }")
if 'fonts.googleapis' in src: sys.exit('build_web: remote font reference left')

head = '''<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<meta name="format-detection" content="telephone=no">
<style>
:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px);color-scheme:light}
html{box-sizing:border-box;-webkit-text-size-adjust:100%}
body{margin:0;font:14px/1.5 -apple-system,system-ui,sans-serif;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}
textarea,input,.dtext,.mushaf,.ist-text{-webkit-user-select:text;user-select:text}
img{max-width:100%}
[hidden]{display:none!important}
.rem-r{display:flex;align-items:center;gap:10px;flex:none}
.tchip{position:relative;display:inline-flex;align-items:center;justify-content:center;min-width:86px;height:36px;padding:0 12px;border-radius:12px;border:1px solid var(--line);background:var(--glass);font-weight:600;font-size:14px}
.tchip input{position:absolute;inset:0;width:100%;height:100%;opacity:0;-webkit-appearance:none;appearance:none;border:0;background:none;font-size:16px}
.g-ol{margin:0;padding-inline-start:20px;display:flex;flex-direction:column;gap:8px;line-height:1.7}
</style>
</head>
<body>
'''
out = head + src + '\n<script src="native.js"></script>\n</body>\n</html>\n'
web = root / 'App' / 'Web'
(web / 'index.html').write_text(out, encoding='utf-8')
(web / 'native.js').write_text((root / 'tools' / 'native.js').read_text(encoding='utf-8'), encoding='utf-8')
print('index.html', len(out)//1024, 'KB')
