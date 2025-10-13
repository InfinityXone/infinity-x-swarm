import openai
import os

def main():
    print("🤖 Codex Prime Orchestrator Booting...")
    # Example behavior: list agents, simulate command dispatch
    agent_paths = [os.path.join(os.path.expanduser("~/ai/agents"), f) for f in os.listdir(os.path.expanduser("~/ai/agents"))]
    print(f"📡 Connected agents: {agent_paths}")

if __name__ == "__main__":
    main()
