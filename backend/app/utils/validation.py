import os
import re

def validate_files(bot_dir: str) -> bool:
    bot_file = f"{bot_dir}/bot.py"
    req_file = f"{bot_dir}/requirements.txt"
    
    if not os.path.exists(bot_file) or not os.path.exists(req_file):
        return False
    
    # Check file sizes (<10MB)
    if os.path.getsize(bot_file) > 10 * 1024 * 1024 or os.path.getsize(req_file) > 10 * 1024 * 1024:
        return False
    
    # Basic check for malicious code (e.g., os.system)
    with open(bot_file, "r") as f:
        content = f.read()
        if re.search(r"os\.system|subprocess\.run|exec\(", content):
            return False
    
    return True