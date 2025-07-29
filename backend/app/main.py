from fastapi import FastAPI, HTTPException, Depends, UploadFile, File
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
import docker
import sqlite3
import psutil
import os
import shutil
import asyncio
import websockets
from firebase_admin import auth, initialize_app
from git import Repo
from typing import List
import uuid

app = FastAPI()
client = docker.from_env()
initialize_app()  # Firebase Admin SDK
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# SQLite setup
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

# Pydantic Models
class BotCreate(BaseModel):
    repo_url: str | None
    bot_id: str = str(uuid.uuid4())

# Dependency: Get current user
async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        user = auth.verify_id_token(token)
        return user["uid"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

# Clone GitHub repo
async def clone_repo(repo_url: str, bot_id: str):
    try:
        Repo.clone_from(repo_url, f"bots/{bot_id}")
        if not os.path.exists(f"bots/{bot_id}/bot.py"):
            raise Exception("Missing bot.py")
        if not os.path.exists(f"bots/{bot_id}/requirements.txt"):
            raise Exception("Missing requirements.txt")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# Run bot in Docker
async def run_bot(bot_id: str, user_id: str):
    try:
        container = client.containers.run(
            "python:3.11-slim",
            command=f"bash -c 'pip install -r requirements.txt && python bot.py'",
            volumes={f"{os.getcwd()}/bots/{bot_id}": {"bind": "/app", "mode": "rw"}},
            working_dir="/app",
            detach=True,
            mem_limit="256m",  # Resource limit
            cpu_period=100000,
            cpu_quota=50000
        )
        conn.execute(
            "INSERT INTO bots (id, user_id, status, container_id) VALUES (?, ?, ?, ?)",
            (bot_id, user_id, "running", container.id)
        )
        conn.commit()
        return container
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# API: Deploy bot
@app.post("/bots/deploy")
async def deploy_bot(bot: BotCreate, user_id: str = Depends(get_current_user)):
    bot_count = conn.execute(
        "SELECT COUNT(*) FROM bots WHERE user_id = ?", (user_id,)
    ).fetchone()[0]
    if bot_count >= 3:
        raise HTTPException(status_code=400, detail="Limit reached: You can host up to 3 bots only.")

    bot_id = bot.bot_id
    if bot.repo_url:
        await clone_repo(bot.repo_url, bot_id)
    container = await run_bot(bot_id, user_id)
    return {"bot_id": bot_id, "status": "running"}

# API: Upload files
@app.post("/bots/upload/{bot_id}")
async def upload_files(bot_id: str, bot_file: UploadFile = File(...), req_file: UploadFile = File(...), user_id: str = Depends(get_current_user)):
    os.makedirs(f"bots/{bot_id}", exist_ok=True)
    with open(f"bots/{bot_id}/bot.py", "wb") as f:
        f.write(await bot_file.read())
    with open(f"bots/{bot_id}/requirements.txt", "wb") as f:
        f.write(await req_file.read())
    container = await run_bot(bot_id, user_id)
    return {"bot_id": bot_id, "status": "running"}

# WebSocket: Stream logs
@app.websocket("/ws/logs/{bot_id}")
async def stream_logs(websocket: WebSocket, bot_id: str):
    await websocket.accept()
    try:
        container = client.containers.get(
            conn.execute("SELECT container_id FROM bots WHERE id = ?", (bot_id,)).fetchone()[0]
        )
        for log in container.logs(stream=True):
            await websocket.send_text(log.decode("utf-8"))
    except Exception as e:
        await websocket.send_text(f"Error: {str(e)}")
    finally:
        await websocket.close()

# API: Stop bot
@app.post("/bots/{bot_id}/stop")
async def stop_bot(bot_id: str, user_id: str = Depends(get_current_user)):
    try:
        container_id = conn.execute(
            "SELECT container_id FROM bots WHERE id = ? AND user_id = ?", (bot_id, user_id)
        ).fetchone()[0]
        container = client.containers.get(container_id)
        container.stop()
        conn.execute("UPDATE bots SET status = 'stopped' WHERE id = ?", (bot_id,))
        conn.commit()
        return {"status": "stopped"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# API: Restart bot
@app.post("/bots/{bot_id}/restart")
async def restart_bot(bot_id: str, user_id: str = Depends(get_current_user)):
    await stop_bot(bot_id, user_id)
    container = await run_bot(bot_id, user_id)
    return {"status": "running"}

# API: Resource stats
@app.get("/bots/{bot_id}/stats")
async def get_stats(bot_id: str, user_id: str = Depends(get_current_user)):
    try:
        container_id = conn.execute(
            "SELECT container_id FROM bots WHERE id = ? AND user_id = ?", (bot_id, user_id)
        ).fetchone()[0]
        container = client.containers.get(container_id)
        stats = container.stats(stream=False)
        return {
            "cpu_usage": stats["cpu_stats"]["cpu_usage"]["total_usage"],
            "memory_usage": stats["memory_stats"]["usage"],
            "storage": os.path.getsize(f"bots/{bot_id}")
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Background task: Auto-cleanup
async def cleanup_inactive_bots():
    while True:
        bots = conn.execute("SELECT id, container_id FROM bots WHERE status = 'running'").fetchall()
        for bot_id, container_id in bots:
            container = client.containers.get(container_id)
            if container.status != "running":
                conn.execute("UPDATE bots SET status = 'stopped' WHERE id = ?", (bot_id,))
                shutil.rmtree(f"bots/{bot_id}", ignore_errors=True)
        conn.commit()
        await asyncio.sleep(3600)  # Check every hour

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(cleanup_inactive_bots())