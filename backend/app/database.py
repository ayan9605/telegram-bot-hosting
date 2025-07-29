import sqlite3

def init_db():
    conn = sqlite3.connect("bots.db")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS bots (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            repo_url TEXT,
            status TEXT,
            container_id TEXT
        )
    """)
    conn.commit()
    return conn