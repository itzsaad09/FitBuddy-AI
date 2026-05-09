from flask import Blueprint, request, jsonify
import cv2
import numpy as np
import traceback
from .services.pose_detector import process_pose_image

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
            return jsonify({'error': 'Failed to decode image'}), 400

        # Get base64 image from Python AI
        base64_image = process_pose_image(image)

        if base64_image:
            return jsonify({'image': base64_image})
        else:
            # Return detailed error if processing failed
            return jsonify({'error': 'AI processing returned None. Check server logs.'}), 500
            
    except Exception as e:
        # Send the actual error message to Flutter
        error_msg = f"{str(e)}\n{traceback.format_exc()}"
        print(f"CRITICAL ROUTE ERROR: {error_msg}")
        return jsonify({'error': str(e)}), 500
