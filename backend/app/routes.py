from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import cv2
import numpy as np
from app.services.pose_detector import process_pose_image
from app.services.pose_utils import normalize_pose, calculate_angle
from app.services.pose_classifier import classifier

router = APIRouter()

@router.get("/")
async def health_check():
    return {"status": "ok", "message": "FitBuddy AI WebSocket Server is Live"}

@router.websocket("/ws/detect")
async def pose_detection_socket(websocket: WebSocket, target: str = "general"):
    """
    Zero-latency WebSocket endpoint with dynamic angle/form calculation.
    """
    await websocket.accept()
    print(f"AI: ⚡ Client connected. Target: {target}")
    
    try:
        while True:
            data = await websocket.receive_bytes()
            np_arr = np.frombuffer(data, np.uint8)
            image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
            
            if image is not None:
                landmarks = process_pose_image(image)
                classification = "No Data"
                angle = None
                state = "UNKNOWN"
                guidance = "READY"
                
                if landmarks and len(landmarks) >= 33:
                    # Normalized pose vector for fallback/legacy classification
                    normalized = normalize_pose(landmarks)
                    
                    target_lower = target.lower()
                    
                    # 1. BICEPS / TRICEPS / FOREARMS / ARMS
                    if any(x in target_lower for x in ["bicep", "tricep", "arm", "forearm"]):
                        # Left Elbow (Shoulder=11, Elbow=13, Wrist=15)
                        left_angle = calculate_angle(landmarks[11], landmarks[13], landmarks[15])
                        left_v = min(landmarks[11].get('v', 0), landmarks[13].get('v', 0), landmarks[15].get('v', 0))
                        
                        # Right Elbow (Shoulder=12, Elbow=14, Wrist=16)
                        right_angle = calculate_angle(landmarks[12], landmarks[14], landmarks[16])
                        right_v = min(landmarks[12].get('v', 0), landmarks[14].get('v', 0), landmarks[16].get('v', 0))
                        
                        # Use side with better visibility
                        if left_v >= right_v:
                            angle = left_angle
                        else:
                            angle = right_angle
                            
                        if angle < 75:
                            state = "BENT"
                            guidance = "GOOD SQUEEZE! NOW EXTEND"
                        elif angle > 135:
                            state = "STRAIGHT"
                            guidance = "GOOD EXTENSION! NOW CURL"
                        else:
                            state = "MOVING"
                            if angle > 75 and angle < 105:
                                guidance = "CURL HIGHER TO FINISH"
                            elif angle > 105 and angle < 135:
                                guidance = "LOWER ARMS SLOWLY"
                            else:
                                guidance = "KEEP ELBOWS STATIONARY"
                        classification = f"ANGLE: {int(angle)}° ({state})"
                        
                    # 2. QUADS / GLUTES / LEGS / THIGHS / WAIST
                    elif any(x in target_lower for x in ["quad", "glute", "leg", "thigh", "waist", "squat", "lung"]):
                        # Left Knee (Hip=23, Knee=25, Ankle=27)
                        left_angle = calculate_angle(landmarks[23], landmarks[25], landmarks[27])
                        left_v = min(landmarks[23].get('v', 0), landmarks[25].get('v', 0), landmarks[27].get('v', 0))
                        
                        # Right Knee (Hip=24, Knee=26, Ankle=28)
                        right_angle = calculate_angle(landmarks[24], landmarks[26], landmarks[28])
                        right_v = min(landmarks[24].get('v', 0), landmarks[26].get('v', 0), landmarks[28].get('v', 0))
                        
                        if left_v >= right_v:
                            angle = left_angle
                        else:
                            angle = right_angle
                            
                        if angle < 110:
                            state = "BENT"
                            guidance = "GOOD DEPTH! RISE UP"
                        elif angle > 150:
                            state = "STRAIGHT"
                            guidance = "STAND FULLY TO START"
                        else:
                            state = "MOVING"
                            if angle >= 110 and angle < 130:
                                guidance = "SQUAT DEEPER FOR FULL RANGE"
                            elif angle >= 130 and angle < 150:
                                guidance = "CONTROL THE LOWERING PHASE"
                            else:
                                guidance = "KEEP BACK STRAIGHT"
                        classification = f"KNEE: {int(angle)}° ({state})"
                        
                    # 3. SHOULDERS / CHEST / BACK / NECK
                    elif any(x in target_lower for x in ["shoulder", "chest", "back", "neck", "press"]):
                        # Left Shoulder (Hip=23, Shoulder=11, Elbow=13)
                        left_angle = calculate_angle(landmarks[23], landmarks[11], landmarks[13])
                        left_v = min(landmarks[23].get('v', 0), landmarks[11].get('v', 0), landmarks[13].get('v', 0))
                        
                        # Right Shoulder (Hip=24, Shoulder=12, Elbow=14)
                        right_angle = calculate_angle(landmarks[24], landmarks[12], landmarks[14])
                        right_v = min(landmarks[24].get('v', 0), landmarks[12].get('v', 0), landmarks[14].get('v', 0))
                        
                        if left_v >= right_v:
                            angle = left_angle
                        else:
                            angle = right_angle
                            
                        if angle < 75:
                            state = "BENT"
                            guidance = "GOOD CONTRACT! PRESS UP"
                        elif angle > 120:
                            state = "STRAIGHT"
                            guidance = "GOOD EXTENSION! LOWER DOWN"
                        else:
                            state = "MOVING"
                            if angle >= 75 and angle < 95:
                                guidance = "PRESS HIGHER"
                            elif angle >= 95 and angle < 120:
                                guidance = "LOWER DOWN SLOWLY"
                            else:
                                guidance = "KEEP SHOULDERS LEVEL"
                        classification = f"SHOULDER: {int(angle)}° ({state})"
                        
                    # 4. DEFAULT: Run KNN classifier
                    else:
                        classification = classifier.predict(normalized)
                        class_lower = classification.lower()
                        if "down" in class_lower or "bent" in class_lower:
                            state = "BENT"
                            guidance = "HOLD DOWN POSITION"
                        elif "up" in class_lower or "straight" in class_lower:
                            state = "STRAIGHT"
                            guidance = "RETURN TO START"
                        else:
                            state = "MOVING"
                            guidance = "IN MOTION - STABILIZE POSTURE"
                
                await websocket.send_json({
                    "landmarks": landmarks,
                    "classification": classification,
                    "angle": angle,
                    "state": state,
                    "guidance": guidance
                })
            else:
                await websocket.send_json({"error": "Corrupt frame"})
                
    except WebSocketDisconnect:
        print("AI: 🔌 Client disconnected")
    except Exception as e:
        print(f"AI Stream Error: {e}")

