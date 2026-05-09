import cv2
import base64
import numpy as np

_pose_model = None

def get_pose_model():
    global _pose_model
    if _pose_model is None:
        try:
            from mediapipe.solutions import pose as mp_pose
            _pose_model = mp_pose.Pose(
                static_image_mode=True, 
                model_complexity=1,
                min_detection_confidence=0.1, # Extremely sensitive
                min_tracking_confidence=0.1
            )
            print("MediaPipe Pose (DEBUG MODE) initialized.")
        except Exception as e:
            print(f"ERROR: {e}")
    return _pose_model

def process_pose_image(image):
    try:
        from mediapipe.solutions import pose as mp_pose
        from mediapipe.solutions import drawing_utils as mp_drawing
        
        pose = get_pose_model()
        if pose is None or image is None:
            return None

        # Try multiple rotations to find the person
        rotations = [0, cv2.ROTATE_90_CLOCKWISE, cv2.ROTATE_90_COUNTERCLOCKWISE, cv2.ROTATE_180]
        best_results = None
        best_img = None
        found_rot = 0
        
        for rot in rotations:
            temp_img = image if rot == 0 else cv2.rotate(image, rot)
            rgb = cv2.cvtColor(temp_img, cv2.COLOR_BGR2RGB)
            results = pose.process(rgb)
            if results.pose_landmarks:
                best_results = results
                best_img = temp_img
                found_rot = rot
                break

        # 2. If person found, draw on THAT image
        if best_results and best_img is not None:
            mp_drawing.draw_landmarks(
                best_img, 
                best_results.pose_landmarks, 
                mp_pose.POSE_CONNECTIONS,
                mp_drawing.DrawingSpec(color=(0, 255, 0), thickness=6, circle_radius=4),
                mp_drawing.DrawingSpec(color=(0, 0, 255), thickness=6, circle_radius=2)
            )
            
            # Rotate back
            if found_rot == cv2.ROTATE_90_CLOCKWISE:
                image = cv2.rotate(best_img, cv2.ROTATE_90_COUNTERCLOCKWISE)
            elif found_rot == cv2.ROTATE_90_COUNTERCLOCKWISE:
                image = cv2.rotate(best_img, cv2.ROTATE_90_CLOCKWISE)
            elif found_rot == cv2.ROTATE_180:
                image = cv2.rotate(best_img, cv2.ROTATE_180)
            else:
                image = best_img
            
            # Draw "POSE DETECTED" in green
            cv2.putText(image, "POSE DETECTED", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        else:
            # Draw "NO POSE FOUND" in red if AI fails
            cv2.putText(image, "NO POSE FOUND", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

        # 3. Encode to base64
        _, buffer = cv2.imencode('.jpg', image, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
        return base64.b64encode(buffer).decode('utf-8')
        
    except Exception as e:
        print(f"Processing error: {e}")
        return None
