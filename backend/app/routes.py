from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import cv2
import numpy as np
from app.services.pose_detector import process_pose_image

router = APIRouter()

@router.get("/")
async def health_check():
    return {"status": "ok", "message": "FitBuddy AI WebSocket Server is Live"}

@router.websocket("/ws/detect")
async def pose_detection_socket(websocket: WebSocket):
    """
    Zero-latency WebSocket endpoint.
    Receives raw JPG bytes from Flutter, decodes, runs MediaPipe, and streams back JSON.
    """
    await websocket.accept()
    print("AI: ⚡ Client connected to WebSocket stream")
    
    try:
        while True:
            # 1. Wait for binary image data from Flutter
            data = await websocket.receive_bytes()
            
            # 2. Decode the bytes back into a numpy array (OpenCV image)
            np_arr = np.frombuffer(data, np.uint8)
            image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
            
            if image is not None:
                # 3. Process image to get 33 landmarks
                landmarks = process_pose_image(image)
                
                # 4. Stream coordinates back instantly
                await websocket.send_json({"landmarks": landmarks})
            else:
                await websocket.send_json({"error": "Corrupt frame"})
                
    except WebSocketDisconnect:
        print("AI: 🔌 Client disconnected")
    except Exception as e:
        print(f"AI Stream Error: {e}")
