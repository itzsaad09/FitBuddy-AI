from flask import Blueprint, request, jsonify
import cv2
import numpy as np
import base64
from .services.pose_detector import detect_pose_landmarks

main_bp = Blueprint('main', __name__)

@main_bp.route('/detect', methods=['POST'])
def detect_pose():
    try:
        # Get image from request
        file = request.files.get('image')
        if not file:
            return jsonify({'error': 'No image provided'}), 400

        # Read image
        np_img = np.frombuffer(file.read(), np.uint8)
        image = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
        if image is None:
            return jsonify({'error': 'Invalid image'}), 400

        # Run pose detection service
        processed_image = detect_pose_landmarks(image)

        # Encode image with drawn joints to base64
        _, buffer = cv2.imencode('.jpg', processed_image)
        base64_image = base64.b64encode(buffer).decode('utf-8')

        return jsonify({'image': base64_image})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
