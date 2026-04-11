import os
import glob
import sys
import json

# Minimal MCP Server for Learning OS Bridge
# This provides keyword search across ~/Learning-Library and brain logs

LIB_PATH = os.path.expanduser("~/Learning-Library")
BRAIN_PATH = os.path.expanduser("~/.gemini/antigravity/brain")

def query_library(keyword):
    results = []
    # Search in library
    files = glob.glob(f"{LIB_PATH}/**/*.md", recursive=True)
    files += glob.glob(f"{BRAIN_PATH}/**/*.md", recursive=True)
    
    for f in files:
        try:
            with open(f, 'r') as content:
                if keyword.lower() in content.read().lower():
                    results.append(f)
        except:
            continue
    return results[:10] # Return top 10 matches

def handle_request(request):
    try:
        method = request.get("method")
        params = request.get("params", {})
        
        if method == "initialize":
            return {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "learning-os-bridge", "version": "1.0.0"}
            }
        elif method == "tools/list":
            return {
                "tools": [
                    {
                        "name": "query_learning_os",
                        "description": "Searches the Learning-Library and AI Brain for keywords to find technical standards or theory.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {"keyword": {"type": "string"}},
                            "required": ["keyword"]
                        }
                    }
                ]
            }
        elif method == "tools/call":
            name = params.get("name")
            args = params.get("arguments", {})
            if name == "query_learning_os":
                keyword = args.get("keyword")
                matches = query_library(keyword)
                return {"content": [{"type": "text", "text": f"Found matches in: {', '.join(matches)}"}]}
        
        return {"error": {"code": -32601, "message": "Method not found"}}
    except Exception as e:
        return {"error": {"code": -32603, "message": str(e)}}

if __name__ == "__main__":
    for line in sys.stdin:
        req = json.loads(line)
        res = handle_request(req)
        sys.stdout.write(json.dumps(res) + "\n")
        sys.stdout.flush()
