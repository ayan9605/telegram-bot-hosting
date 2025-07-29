import docker
import os
import shutil
from git import Repo
from fastapi import HTTPException
from .utils.validation import validate_files

client = docker.from_env()

async def clone_repo(repo_url: str, bot_id: str):
    try:
        Repo.clone_from(repo_url, f"bots/{bot_id}")
        if not validate_files(f"bots/{bot_id}"):
            shutil.rmtree(f"bots/{bot_id}", ignore_errors=True)
            raise HTTPException(status_code=400, detail="Invalid or missing bot.py/requirements.txt")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to clone repo: {str(e)}")

async def run_bot(bot_id: str, user_id: str):
    try:
        container = client.containers.run(
            "python:3.11-slim",
            command="bash -c 'pip install -r requirements.txt && python bot.py'",
            volumes={f"{os.getcwd()}/bots/{bot_id}": {"bind": "/app", "mode": "rw"}},
            working_dir="/app",
            detach=True,
            mem_limit="256m",
            cpu_period=100000,
            cpu_quota=50000
        )
        return container
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to run bot: {str(e)}")

async def get_bot_stats(container_id: str):
    try:
        container = client.containers.get(container_id)
        stats = container.stats(stream=False)
        return {
            "cpu_usage": stats["cpu_stats"]["cpu_usage"]["total_usage"],
            "memory_usage": stats["memory_stats"]["usage"],
            "storage": os.path.getsize(f"bots/{container_id}")
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get stats: {str(e)}")