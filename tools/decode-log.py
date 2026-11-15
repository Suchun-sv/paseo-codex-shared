import json,sys
for l in open(sys.argv[1]):
    e=json.loads(l); d=e['data']
    if e['dir']=='meta': print(e['t'][11:19], 'META', d); continue
    try: m=json.loads(d)
    except Exception: print(e['t'][11:19], e['dir'], 'RAW', d[:200]); continue
    mid=m.get('id'); meth=m.get('method')
    p=m.get('params') or {}
    tid=p.get('threadId') or (p.get('turn') or {}).get('threadId') if isinstance(p,dict) else None
    turn=(p.get('turn') or {}).get('id') if isinstance(p,dict) else None
    summ=''
    if 'result' in m: summ='RESULT '+json.dumps(m['result'],ensure_ascii=False)[:160]
    elif 'error' in m: summ='ERROR '+json.dumps(m['error'],ensure_ascii=False)[:200]
    else: summ=json.dumps(p,ensure_ascii=False)[:160]
    print(e['t'][11:19], '>>' if e['dir'].startswith('paseo') else '<<', f'id={mid}' if mid is not None else '', meth or '', f'thread={tid}' if tid else '', f'turn={turn}' if turn else '', '|', summ)
