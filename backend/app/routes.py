from flask import Blueprint, request, jsonify
import cv2
import numpy as np
from .services.pose_detector import get_pose_landmarks

main_bp = Blueprint('main', __name__)

@main_bp.route('/', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok', 'message': 'FitBuddy AI backend is running'}), 200

@main_bp.route('/detect', methods=['POST'])
def detect_pose():
    try:
        file = request.files.get('image')
        if not file:
            return jsonify({'error': 'No image provided'}), 400

        np_img = np.frombuffer(file.read(), np.uint8)
        image = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
        if image is None:
            return jsonify({'error': 'Invalid image'}), 400

        # Return landmarks instead of the processed image
        landmarks = get_pose_landmarks(image)

        return jsonify({'landmarks': landmarks})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
