"""Extract text properties, including compact DFM column collections."""
import re

def decode(value):
    result=[]
    for token in re.findall(r"'(?:[^']|'')*'|#\d+",value):
        result.append(chr(int(token[1:])) if token.startswith('#') else token[1:-1].replace("''", "'"))
    return ''.join(result)

def entries(path):
    stack=[];root=None;column=None;index=-1
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        indent=len(line)-len(line.lstrip())
        obj=re.match(r'\s*object (\w+): (\w+)',line)
        if obj:
            while stack and stack[-1][0]>=indent:stack.pop()
            stack.append((indent,obj[1]));root=root or obj[1];continue
        if not stack:continue
        if line.strip()=='end' and indent==stack[-1][0]:stack.pop();continue
        if 'Columns = <' in line:column=stack[-1][1];index=-1;continue
        if column:
            if re.match(r'\s*item\b',line):index+=1
            caption=re.search(r'\bCaption = (.*?)(?:\s+Width =|\s+end\b|$)',line)
            if caption:yield f'{root}.{column}.Columns.{index}',decode(caption[1])
            if '>' in line:column=None
            continue
        prop=re.match(r'\s*(Caption|Hint|Title|Filter) = (.*)',line)
        if prop:yield f'{root}.{stack[-1][1]}.{prop[1]}',decode(prop[2])
