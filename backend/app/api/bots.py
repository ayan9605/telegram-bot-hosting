from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, WebSocket
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
import sqlite3
import uuid
from firebase_admin import auth
from .services.bot_service import clone_repo, run_bot, get_bot_stats
import os
import docker

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
client = docker.from_env()
conn = sqlite3.connect("bots.db")

class BotCreate(BaseModel):
    repo_url: str | None
    bot_id: str = str(uuid.uuid4())

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        user = auth.verify_id_token(token)
        return user["uid"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

@router.post("/deploy")
async def deploy_bot(bot: BotCreate, user_id: str = Depends(get_current_user)):
    bot_count = conn.execute(
        "SELECT COUNT(*) FROM bots WHERE user_id = ?", (user_id,)
    ).fetchone()[0]
    if bot_count >= 3:
        raise HTTPException(status_code=400, detail="Limit reached: You can host up to 3 bots only.")

    bot_id = bot.bot_id
    os.makedirs(f"bots/{bot_id}", exist_ok=True)
    if bot.repo_url:
        await clone_repo(bot.repo_url, bot_id)
    container = await run_bot(bot_id, user_id)
    conn.execute(
        "INSERT INTO bots (id, user_id, repo_url, status, container_id) VALUES (?, ?, ?, ?, ?)",
        (bot_id, user_id, bot.repo_url, "running", container.id)
    )
    conn.commit()
    return {"bot_id": bot_id, "status": "running"}

@router.post("/upload/{bot_id}")
async def upload_files(bot_id: str, bot_file: UploadFile = File(...), req_file: UploadFile = File(...), user_id: str = Depends(get_current_user)):
    bot_count = conn.execute(
        "SELECT COUNT(*) FROM bots WHERE user_id = ?", (user_id,)
    ).fetchone()[0]
    if bot_count >= 3:
        raise HTTPException(status_code=400, detail="Limit reached: You can host up to 3 bots only.")

    os.makedirs(f"bots/{bot_id}", exist_ok=True)
    with open(f"bots/{bot_id}/bot.py", "wb") as f:
        f.write(await bot_file.read())
    with open(f"bots/{bot_id}/requirements.txt", "wb") as f:
        f.write(await req_file.read())
    
    if not validate_files(f"bots/{bot_id}"):
        raise HTTPException(status_code=400, detail="Invalid or malicious files")
    
    container = await run_bot(bot_id, user_id)
    conn.execute(
        "INSERT INTO bots (id, user_id, status, container_id) VALUES (?, ?, ?, ?)",
        (bot_id, user_id, "running", container.id)
    )
    conn.commit()
    return {"bot_id": bot_id, "status": "running"}

@router.websocket("/logs/{bot_id}")
async def stream_logs(websocket: WebSocket, bot_id: str):
    await websocket.accept()
    try:
        container_id = conn.execute(
            "SELECT container_id FROM bots WHERE id = ?", (bot_id,)
        ).fetchone()[0]
        container = client.containers.get(container_id)
        for log in container.logs(stream=True):
            await websocket.send_text(log.decode("utf-8"))
    except Exception as e:
        await websocket.send_text(f"Error: {str(e)}")
    finally:
        await websocket.close()

@router.post("/{bot_id}/stop")
async def stop_bot(bot_id: str, user_id: str = Depends(get_current_user)):
    container_id = conn.execute(
        "SELECT container_id FROM bots WHERE id = ? AND user_id = ?", (bot_id, user_id)
    ).fetchone()
    if not container_id:
        raise HTTPException(status_code=404, detail="Bot not found")
    container = client.containers.get(container_id[0])
    container.stop()
    conn.execute("UPDATE bots SET status = 'stopped' WHERE id = ?", (bot_id,))
    conn.commit()
    return {"status": "stopped"}

@router.post("/{bot_id}/restart")
async def restart_bot(bot_id: str, user_id: str = Depends(get_current_user)):
    container_id = conn.execute(
        "SELECT container_id FROM bots WHERE id = ? AND user_id = ?", (bot_id, user_id)
    ).fetchone()
    if not container_id:
        raise HTTPException(status_code=404, detail="Bot not found")
    container = client.containers.get(container_id[0])
    container.stop()
    container = await run_bot(bot_id, user_id)
    conn.execute("UPDATE bots SET status = 'running', container_id = ? WHERE id = ?", (container.id, bot_id))
    conn.commit()
    return {"status": "running"}

@router.get("/{bot_id}/stats")
async def get_stats(bot_id: str, user_id: str = Depends(get_current_user)):
    container_id = conn.execute(
        "SELECT container_id FROM bots WHERE id = ? AND user_id = ?", (bot_id, user_id)
    ).fetchone()
    if not container_id:
        raise HTTPException(status_code=404, detail="Bot not found")
    return await get_bot_stats(container_id[0])