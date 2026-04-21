import os
import glob
import re

print('Starting comment fix script...')
directory = r"c:\Users\Usuario\OneDrive\Escritorio\Click_v2\click_v2\lib\servicios"
widgets_dir = r"c:\Users\Usuario\OneDrive\Escritorio\Click_v2\click_v2\lib\widgets"

files = glob.glob(os.path.join(directory, '*.dart')) + glob.glob(os.path.join(widgets_dir, '*.dart'))

recovered = 0
for file in files:
    try:
        with open(file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # We need to find comments (/// or //) that are sharing a line with code.
        # usually separated by 2 or more spaces, or specific keywords.
        
        # Split by 2 or more spaces after a comment
        new_content = re.sub(r'(///.*?|//.*?)\s{2,}', r'\1\n  ', content)
        
        # Also split if there's exactly 1 space followed by standard keywords
        keywords = ['void', 'Future', 'String', 'bool', 'Map', 'List', 'int', 'double', 'final', 'const', 'static', 'Stream', 'StreamSubscription', 'StreamController', 'return', 'if', 'for', 'else', 'try', 'catch', 'await']
        for kw in keywords:
            new_content = re.sub(r'(///.*?|//.*?)\s+(' + kw + r')\b', r'\1\n  \2', new_content)
        
        # Sometimes '}' gets stuck in comments
        new_content = re.sub(r'(///.*?|//.*?)\s+\}', r'\1\n}', new_content)
        
        if content != new_content:
            with open(file, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Fixed comments in {file}")
            recovered += 1
    except Exception as e:
        print(f"Error on {file}: {e}")

print(f"Fixed {recovered} files.")
