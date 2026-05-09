import cv2
import base64
import numpy as np

# Global model variable
_pose_model = None

def get_pose_model():
    global _pose_model
    if _pose_model is None:
        try:
            # Import inside here to prevent startup crashes
            from mediapipe.solutions import pose as mp_pose
            
            # model_complexity=0 is the LIGHTEST possible model for weak servers
            _pose_model = mp_pose.Pose(
                static_image_mode=True, 
                model_complexity=0,
                min_detection_confidence=0.3,
                min_tracking_confidence=0.3
            )
            print("AI MODEL LOADED: Complexity 0 (Lightweight)")
        except Exception as e:
            print(f"FATAL: Could not load MediaPipe: {e}")
    return _pose_model

def process_pose_image(image):
    try:
        # Import utilities at top level of function
        from mediapipe.solutions import pose as mp_pose
        from mediapipe.solutions import drawing_utils as mp_drawing
        
        pose = get_pose_model()
        if pose is None:
            print("ERROR: AI Model is None. Possible memory issue on server.")
            return None
            
        if image is None:
            print("ERROR: Received empty image")
            return None

        # Convert to RGB
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # Run AI detection
        results = pose.process(rgb)

        # Draw even if no pose found (the debug text)
        if results.pose_landmarks:
            mp_drawing.draw_landmarks(
                image, 
                results.pose_landmarks, 
                mp_pose.POSE_CONNECTIONS,
                mp_drawing.DrawingSpec(color=(0, 255, 0), thickness=5, circle_radius=3),
                mp_drawing.DrawingSpec(color=(0, 0, 255), thickness=5, circle_radius=1)
            )
            cv2.putText(image, "POSE DETECTED", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        else:
            cv2.putText(image, "NO POSE FOUND", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

        # Encode back to base64
        _, buffer = cv2.imencode('.jpg', image, [int(cv2.IMWRITE_JPEG_QUALITY), 70])
        return base64.b64encode(buffer).decode('utf-8')
        
    except Exception as e:
        print(f"PROCESS_POSE_IMAGE CRASHED: {e}")
        return None
