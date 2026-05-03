import cv2

_pose_model = None

def get_pose_model():
    global _pose_model
    if _pose_model is None:
        import mediapipe as mp
        mp_pose = mp.solutions.pose
        _pose_model = mp_pose.Pose(
            static_image_mode=False,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
    return _pose_model

def detect_pose_landmarks(image):
    try:
        import mediapipe as mp
        mp_pose = mp.solutions.pose
        mp_drawing = mp.solutions.drawing_utils

        pose = get_pose_model()

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
    except Exception as e:
        print(f"Error in pose detection: {e}")

    return image
