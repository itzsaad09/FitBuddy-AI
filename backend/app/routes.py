from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import cv2
import numpy as np
from app.services.pose_detector import process_pose_image
from app.services.pose_utils import normalize_pose
from app.services.pose_classifier import classifier

router = APIRouter()

@router.get("/")
async def health_check():
    return {"status": "ok", "message": "FitBuddy AI WebSocket Server is Live"}

@router.websocket("/ws/detect")
async def pose_detection_socket(websocket: WebSocket):
    """
    Zero-latency WebSocket endpoint.
    """
    await websocket.accept()
    print("AI: ⚡ Client connected")
    
    try:
        while True:
            data = await websocket.receive_bytes()
            np_arr = np.frombuffer(data, np.uint8)
            image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
            
            if image is not None:
                landmarks = process_pose_image(image)
                classification = "No Data"
                if landmarks:
                    normalized = normalize_pose(landmarks)
                    classification = classifier.predict(normalized)
                
                await websocket.send_json({
                    "landmarks": landmarks,
                    "classification": classification
                })
            else:
                await websocket.send_json({"error": "Corrupt frame"})
                
    except WebSocketDisconnect:
        print("AI: 🔌 Client disconnected")
    except Exception as e:
        print(f"AI Stream Error: {e}")
