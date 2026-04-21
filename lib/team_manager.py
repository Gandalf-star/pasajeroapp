import json
import os
import sys
import fcntl  # Importante para evitar colisiones de escritura (Sistemas Unix/Mac/Linux)

TEAM_DIR = ".antigravity/team"

def init_team():
    """Inicializa la infraestructura del equipo."""
    os.makedirs(f"{TEAM_DIR}/mailbox", exist_ok=True)
    os.makedirs(f"{TEAM_DIR}/locks", exist_ok=True)
    
    tasks_path = f"{TEAM_DIR}/tasks.json"
    if not os.path.exists(tasks_path):
        with open(tasks_path, 'w') as f:
            json.dump({"tasks": [], "members": ["director", "frontend", "backend", "revisor"]}, f, indent=2)
            
    broadcast_path = f"{TEAM_DIR}/broadcast.msg"
    if not os.path.exists(broadcast_path):
        with open(broadcast_path, 'w') as f: 
            f.write("")
            
    print("✓ Infraestructura 'Equipo Alejabot' lista.")

def assign_task(title, assigned_to, deps=[]):
    """Asigna una nueva tarea de forma segura con soporte para dependencias."""
    path = f"{TEAM_DIR}/tasks.json"
    with open(path, 'r+') as f:
        fcntl.flock(f, fcntl.LOCK_EX) # Bloquea el archivo
        try:
            data = json.load(f)
            task = {
                "id": len(data["tasks"]) + 1,
                "title": title,
                "status": "PENDING",
                "assigned_to": assigned_to,
                "dependencies": deps
            }
            data["tasks"].append(task)
            f.seek(0)
            json.dump(data, f, indent=2)
            f.truncate()
            print(f"✓ Tarea {task['id']} ({title}) asignada a {assigned_to}.")
        except Exception as e:
            print(f"Error al asignar tarea: {e}")
        finally:
            fcntl.flock(f, fcntl.LOCK_UN) # Libera el archivo

def broadcast(sender, text):
    """Envía un mensaje a todos los miembros del equipo."""
    msg = {"de": sender, "tipo": "BROADCAST", "mensaje": text}
    with open(f"{TEAM_DIR}/broadcast.msg", 'a') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write(json.dumps(msg) + "\n")
        fcntl.flock(f, fcntl.LOCK_UN)
    print(f"✓ Mensaje global enviado por {sender}.")

def send_message(sender, receiver, text):
    """Envía un mensaje al buzón de un agente específico."""
    path = f"{TEAM_DIR}/mailbox/{receiver}.msg"
    msg = {"de": sender, "mensaje": text}
    with open(path, 'a') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write(json.dumps(msg) + "\n")
        fcntl.flock(f, fcntl.LOCK_UN)
    print(f"✓ Mensaje enviado de {sender} a {receiver}.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python team_manager.py [init | assign | broadcast | send_message] ...")
        sys.exit(1)

    cmd = sys.argv[1]
    
    if cmd == "init":
        init_team()
    elif cmd == "assign" and len(sys.argv) >= 4:
        # Uso: python team_manager.py assign "Titulo" "rol" "dep1,dep2"
        deps = sys.argv[4].split(',') if len(sys.argv) > 4 else []
        assign_task(sys.argv[2], sys.argv[3], deps)
    elif cmd == "broadcast" and len(sys.argv) == 4:
        broadcast(sys.argv[2], sys.argv[3])
    elif cmd == "send_message" and len(sys.argv) == 5:
        # Uso: python team_manager.py send_message "remitente" "destinatario" "mensaje"
        send_message(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        print("Comando o argumentos inválidos.")