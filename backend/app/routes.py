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
async def pose_detection_socket(websocket: WebSocket, target: str = "general", exercise: str = ""):
    """
    Zero-latency WebSocket endpoint with dynamic angle/form calculation.
    """
    await websocket.accept()
    print(f"AI: ⚡ Client connected. Target: {target}, Exercise: {exercise}")
    
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
                    exercise_lower = exercise.lower()
                    
                    # 1. SHOULDER RAISES / FLIES (Shoulder joint: Hip-Shoulder-Elbow)
                    if any(x in target_lower or x in exercise_lower for x in ["raise", "fly", "lateral"]):
                        # Left Shoulder (Hip=23, Shoulder=11, Elbow=13)
                        left_angle = calculate_angle(landmarks[23], landmarks[11], landmarks[13])
                        left_v = min(landmarks[11].get('v', 0), landmarks[13].get('v', 0)) # Only require Shoulder and Elbow
                        
                        # Right Shoulder (Hip=24, Shoulder=12, Elbow=14)
                        right_angle = calculate_angle(landmarks[24], landmarks[12], landmarks[14])
                        right_v = min(landmarks[12].get('v', 0), landmarks[14].get('v', 0)) # Only require Shoulder and Elbow
                        
                        if max(left_v, right_v) < 0.3:
                            state = "UNKNOWN"
                            guidance = "ALIGN YOUR BODY IN FRAME"
                            classification = "WAITING..."
                        else:
                            angle = left_angle if left_v >= right_v else right_angle
                            if angle > 80:
                                state = "BENT"
                                guidance = "GOOD HEIGHT! LOWER SLOWLY"
                            elif angle < 40:
                                state = "STRAIGHT"
                                guidance = "START POSITION - RAISE ARMS"
                            else:
                                state = "MOVING"
                                guidance = "CONTROL THE MOTION"
                            classification = f"SHOULDER: {int(angle)}° ({state})"
                        
                    # 2. ARMS (Elbow joint: Shoulder-Elbow-Wrist)
                    elif any(x in target_lower for x in ["bicep", "tricep", "arm", "forearm"]):
                        # Left Elbow (Shoulder=11, Elbow=13, Wrist=15)
                        left_angle = calculate_angle(landmarks[11], landmarks[13], landmarks[15])
                        left_v = min(landmarks[11].get('v', 0), landmarks[13].get('v', 0), landmarks[15].get('v', 0))
                        
                        # Right Elbow (Shoulder=12, Elbow=14, Wrist=16)
                        right_angle = calculate_angle(landmarks[12], landmarks[14], landmarks[16])
                        right_v = min(landmarks[12].get('v', 0), landmarks[14].get('v', 0), landmarks[16].get('v', 0))
                        
                        if max(left_v, right_v) < 0.3:
                            state = "UNKNOWN"
                            guidance = "ALIGN YOUR BODY IN FRAME"
                            classification = "WAITING..."
                        else:
                            angle = left_angle if left_v >= right_v else right_angle
                            if angle < 90:
                                state = "BENT"
                                guidance = "GOOD RANGE! NOW EXTEND"
                            elif angle > 135:
                                state = "STRAIGHT"
                                guidance = "START POSITION - BEGIN REP"
                            else:
                                state = "MOVING"
                                guidance = "IN MOTION - CONTROL THE TEMPO"
                            classification = f"ANGLE: {int(angle)}° ({state})"
                        
                    # 3. LEGS (Knee joint: Hip-Knee-Ankle)
                    elif any(x in target_lower for x in ["quad", "glute", "hamstring", "calves", "adductor", "abductor", "leg", "thigh", "squat", "lung"]):
                        # Left Knee (Hip=23, Knee=25, Ankle=27)
                        left_angle = calculate_angle(landmarks[23], landmarks[25], landmarks[27])
                        left_v = min(landmarks[23].get('v', 0), landmarks[25].get('v', 0)) # Only require Hip and Knee
                        
                        # Right Knee (Hip=24, Knee=26, Ankle=28)
                        right_angle = calculate_angle(landmarks[24], landmarks[26], landmarks[28])
                        right_v = min(landmarks[24].get('v', 0), landmarks[26].get('v', 0)) # Only require Hip and Knee
                        
                        if max(left_v, right_v) < 0.3:
                            state = "UNKNOWN"
                            guidance = "ALIGN YOUR BODY IN FRAME"
                            classification = "WAITING..."
                        else:
                            angle = left_angle if left_v >= right_v else right_angle
                            if angle < 115:
                                state = "BENT"
                                guidance = "GOOD DEPTH! RISE UP"
                            elif angle > 145:
                                state = "STRAIGHT"
                                guidance = "STAND STRAIGHT - GO DOWN"
                            else:
                                state = "MOVING"
                                guidance = "KEEP CONTROL - KEEP BALANCED"
                            classification = f"KNEE: {int(angle)}° ({state})"
                        
                    # 4. ABS / CORE (Hip joint: Shoulder-Hip-Knee)
                    elif any(x in target_lower for x in ["abs", "core", "abdominal", "situp", "crunch"]):
                        # Left Hip (Shoulder=11, Hip=23, Knee=25)
                        left_angle = calculate_angle(landmarks[11], landmarks[23], landmarks[25])
                        left_v = min(landmarks[11].get('v', 0), landmarks[23].get('v', 0)) # Only require Shoulder and Hip
                        
                        # Right Hip (Shoulder=12, Hip=24, Knee=26)
                        right_angle = calculate_angle(landmarks[12], landmarks[24], landmarks[26])
                        right_v = min(landmarks[12].get('v', 0), landmarks[24].get('v', 0)) # Only require Shoulder and Hip
                        
                        if max(left_v, right_v) < 0.3:
                            state = "UNKNOWN"
                            guidance = "ALIGN YOUR BODY IN FRAME"
                            classification = "WAITING..."
                        else:
                            angle = left_angle if left_v >= right_v else right_angle
                            if angle < 100:
                                state = "BENT"
                                guidance = "GOOD SQUEEZE! LOWER DOWN"
                            elif angle > 140:
                                state = "STRAIGHT"
                                guidance = "LIE FLAT - START CRUNCH"
                            else:
                                state = "MOVING"
                                guidance = "ENGAGE YOUR CORE"
                            classification = f"HIP: {int(angle)}° ({state})"
                        
                    # 5. UPPER BODY COMPOUND PRESS / PULL (Elbow joint: Shoulder-Elbow-Wrist)
                    elif any(x in target_lower or x in exercise_lower for x in ["pectoral", "lats", "back", "trap", "delts", "deltoid", "serratus", "scapulae", "spine", "shoulder", "chest", "neck", "press"]):
                        # Left Elbow (Shoulder=11, Elbow=13, Wrist=15)
                        left_angle = calculate_angle(landmarks[11], landmarks[13], landmarks[15])
                        left_v = min(landmarks[11].get('v', 0), landmarks[13].get('v', 0)) # Only require Shoulder and Elbow
                        
                        # Right Elbow (Shoulder=12, Elbow=14, Wrist=16)
                        right_angle = calculate_angle(landmarks[12], landmarks[14], landmarks[16])
                        right_v = min(landmarks[12].get('v', 0), landmarks[14].get('v', 0)) # Only require Shoulder and Elbow
                        
                        if max(left_v, right_v) < 0.3:
                            state = "UNKNOWN"
                            guidance = "ALIGN YOUR BODY IN FRAME"
                            classification = "WAITING..."
                        else:
                            angle = left_angle if left_v >= right_v else right_angle
                            if angle < 90:
                                state = "BENT"
                                guidance = "GOOD RANGE! NOW EXTEND"
                            elif angle > 135:
                                state = "STRAIGHT"
                                guidance = "START POSITION - BEGIN REP"
                            else:
                                state = "MOVING"
                                guidance = "IN MOTION - CONTROL THE TEMPO"
                            classification = f"ANGLE: {int(angle)}° ({state})"
                        
                    # 6. DEFAULT FALLBACK: Run KNN classifier and monitor single relevant joint
                    else:
                        classification = classifier.predict(normalized)
                        
                        left_elbow = calculate_angle(landmarks[11], landmarks[13], landmarks[15])
                        right_elbow = calculate_angle(landmarks[12], landmarks[14], landmarks[16])
                        left_knee = calculate_angle(landmarks[23], landmarks[25], landmarks[27])
                        right_knee = calculate_angle(landmarks[24], landmarks[26], landmarks[28])
                        left_hip = calculate_angle(landmarks[11], landmarks[23], landmarks[25])
                        right_hip = calculate_angle(landmarks[12], landmarks[24], landmarks[26])
                        
                        class_lower = classification.lower()
                        
                        # Monitor relevant joint only
                        if "squat" in class_lower or "jack" in class_lower:
                            left_v = min(landmarks[23].get('v', 0), landmarks[25].get('v', 0))
                            right_v = min(landmarks[24].get('v', 0), landmarks[26].get('v', 0))
                            
                            if max(left_v, right_v) < 0.3:
                                state = "UNKNOWN"
                                guidance = "ALIGN YOUR BODY IN FRAME"
                                classification = "WAITING..."
                            else:
                                angle = left_knee if left_v >= right_v else right_knee
                                if angle < 115:
                                    state = "BENT"
                                    guidance = "GOOD DEPTH! RISE UP"
                                elif angle > 145:
                                    state = "STRAIGHT"
                                    guidance = "STAND STRAIGHT - GO DOWN"
                                else:
                                    state = "MOVING"
                                    guidance = "KEEP CONTROL - KEEP BALANCED"
                                
                        elif "situp" in class_lower or "crunch" in class_lower:
                            left_v = min(landmarks[11].get('v', 0), landmarks[23].get('v', 0))
                            right_v = min(landmarks[12].get('v', 0), landmarks[24].get('v', 0))
                            
                            if max(left_v, right_v) < 0.3:
                                state = "UNKNOWN"
                                guidance = "ALIGN YOUR BODY IN FRAME"
                                classification = "WAITING..."
                            else:
                                angle = left_hip if left_v >= right_v else right_hip
                                if angle < 100:
                                    state = "BENT"
                                    guidance = "GOOD SQUEEZE! LOWER DOWN"
                                elif angle > 140:
                                    state = "STRAIGHT"
                                    guidance = "LIE FLAT - START CRUNCH"
                                else:
                                    state = "MOVING"
                                    guidance = "ENGAGE YOUR CORE"
                                
                        else:  # push_up, pull_up, or general upper body
                            left_v = min(landmarks[11].get('v', 0), landmarks[13].get('v', 0))
                            right_v = min(landmarks[12].get('v', 0), landmarks[14].get('v', 0))
                            
                            if max(left_v, right_v) < 0.3:
                                state = "UNKNOWN"
                                guidance = "ALIGN YOUR BODY IN FRAME"
                                classification = "WAITING..."
                            else:
                                angle = left_elbow if left_v >= right_v else right_elbow
                                if angle < 90:
                                    state = "BENT"
                                    guidance = "GOOD RANGE! NOW EXTEND"
                                elif angle > 135:
                                    state = "STRAIGHT"
                                    guidance = "START POSITION - BEGIN REP"
                                else:
                                    state = "MOVING"
                                    guidance = "IN MOTION - CONTROL THE TEMPO"
                
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

