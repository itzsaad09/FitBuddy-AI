import cv2
from mediapipe.solutions import pose as mp_pose
from mediapipe.solutions import drawing_utils as mp_drawing

pose = mp_pose.Pose(static_image_mode=False, min_detection_confidence=0.5, min_tracking_confidence=0.5)

def detect_pose_landmarks(image):
    # Convert to RGB for MediaPipe
    rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = pose.process(rgb_image)

    # Draw on the original image
    if results.pose_landmarks:
        mp_drawing.draw_landmarks(
            image,
            results.pose_landmarks,
            mp_pose.POSE_CONNECTIONS,
            mp_drawing.DrawingSpec(color=(0, 255, 0), thickness=5, circle_radius=4), # joints
            mp_drawing.DrawingSpec(color=(0, 0, 255), thickness=4, circle_radius=2)  # connections
        )
    return image
