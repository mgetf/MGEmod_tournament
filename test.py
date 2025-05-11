import asyncio
import websockets
import json

# Define the host and port the server will listen on.
# Make sure your ngrok setup forwards to this host and port.
HOST = "localhost"
PORT = 8083  # You can change this, but ensure ngrok points to the same port
EXPECTED_PATH = "/endpoint"

async def handler(websocket, path):
    """
    Handles incoming WebSocket connections.
    """
    client_address = websocket.remote_address
    print(f"Client connected: {client_address}, Path: {path}")

    if path == EXPECTED_PATH:
        try:
            # Keep the connection open and listen for messages
            async for message in websocket:
                print(f"<- Received from {client_address}: {message}")

                # Attempt to parse the message as JSON
                try:
                    data = json.loads(message)
                    print(f"   Parsed JSON: {data}")

                    # Example: Respond to a "ServerHello" message
                    if isinstance(data, dict) and data.get("type") == "ServerHello":
                        response = {
                            "type": "PythonServerAck",
                            "payload": {
                                "status": "received_hello",
                                "message": f"Hello acknowledged from Python server for client {client_address}!"
                            }
                        }
                        await websocket.send(json.dumps(response))
                        print(f"-> Sent to {client_address}: {json.dumps(response)}")
                
                except json.JSONDecodeError:
                    print("   Received non-JSON message or malformed JSON.")
                    # Optionally, send an error message back
                    # await websocket.send(json.dumps({"error": "Invalid JSON received"}))
                except Exception as e:
                    print(f"   Error processing message: {e}")

        except websockets.exceptions.ConnectionClosedOK:
            print(f"Client {client_address} disconnected gracefully.")
        except websockets.exceptions.ConnectionClosedError as e:
            print(f"Client {client_address} disconnected with error: {e}")
        except Exception as e:
            print(f"An unexpected error occurred with {client_address}: {e}")
        finally:
            print(f"Connection with {client_address} (Path: {path}) closed.")
    else:
        print(f"Connection attempt to unexpected path '{path}' from {client_address}. Closing.")
        # Optionally send an HTTP-like error if not using a raw WebSocket close
        # For simplicity, just closing the WebSocket connection here.
        await websocket.close(code=1008, reason="Policy Violation: Unexpected path")


async def main():
    """
    Starts the WebSocket server.
    """
    # The `ws_handler` argument to `websockets.serve` is our `handler` function.
    # It will be called for each new connection.
    async with websockets.serve(handler, HOST, PORT):
        print(f"WebSocket server started on ws://{HOST}:{PORT}")
        print(f"Expecting connections on path: {EXPECTED_PATH}")
        print("Press Ctrl+C to stop the server.")
        await asyncio.Future()  # Run forever until interrupted

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nWebSocket server stopping...")
