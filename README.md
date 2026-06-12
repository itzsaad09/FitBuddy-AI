# FitBuddy AI - AI-Powered Personal Workout Assistant

FitBuddy AI is an intelligent fitness companion designed to guide users through their workouts, track their long-term progress, and analyze their movement form in real-time. By utilizing a native mobile frontend combined with a dedicated machine learning backend, it provides instant corrective feedback and handles user workouts with high portability.

## Project Structure

The project is split into two primary components:
1. **Frontend**: A Flutter-based cross-platform application that manages the user profile, exercises library, workout plans, weekly statistics, and the camera interface.
2. **Backend**: A FastAPI Python server that runs computer vision pipelines to analyze video frames and perform real-time pose tracking.

---

## Backend Engine (FastAPI & Python)

The backend acts as a high-performance measurement engine. It handles frame-by-frame analysis of the user's exercise form over a network connection.

### Core Features

* **Real-Time WebSocket Protocol**: Operates a lightweight connection under the `/ws/detect` endpoint to accept binary image buffers from the client app.
* **Pose Landmark Detection**: Leverages Google MediaPipe Pose to detect and map 33 distinct 3D skeletal keypoints on the user's body.
* **Form & Angle Calculations**: Uses custom trigonometric formulas to calculate exact angles at major joints, including:
  * Arm/Elbow Joint (Shoulder-Elbow-Wrist) for curl variants.
  * Shoulder Joint (Hip-Shoulder-Elbow) for raises and flies.
  * Knee/Leg Joint (Hip-Knee-Ankle) for squat exercises.
* **Dynamic Feedback and Guidance**: Compares calculated angles against a local exercise database (based on CSV definitions) to check if the range of motion is correct, providing visual guidance (e.g., "Keep lowering," "Good height," "Extend fully") and incrementing repetition counts.

### Tech Stack

* FastAPI and Uvicorn for asynchronous high-concurrency routing.
* OpenCV for image decoding and buffer manipulation.
* MediaPipe for skeletal landmark detection.
* NumPy, Pandas, and Scikit-Learn for coordinate scaling and classification.

---

## Frontend Application (Flutter & Dart)

The frontend offers a clean, modern user interface, handling local database management, generative AI plan configuration, and media capturing.

### Core Features

* **Personalized Onboarding**: Allows users to specify their experience levels, focus areas, and customize individual fitness parameters.
* **Workout Routine Generation**: Integrates with the Google Generative AI (Gemini) SDK to dynamically create customized workout plans based on user profiles.
* **Interactive AI Workout Session**:
  * Utilizes the device camera feed to stream frames to the backend WebSocket server.
  * Renders overlay guides showing current joint angles, repetition targets, and immediate performance guidance text.
* **Progress Dashboard**: Aggregates exercise records to display weekly statistics, total repetitions performed, and a detailed chronological history log.
* **Offline Storage & SQLite**: Uses `sqflite` to store exercise catalogs, customized workout plans, and workout completion logs locally on the device.
* **Backup & Restore Portability**:
  * **Export**: Generates a standard JSON database dump, writes it to a temporary file, and presents it to the native system share sheet (allowing users to save to their local filesystem, send via email, or upload to cloud storage).
  * **Import**: Invokes the native file picker to let the user select a valid JSON backup file and restores the local database state.

---

## Getting Started

### Prerequisites

* Flutter SDK (3.9.x or higher)
* Python (3.9 to 3.11 recommended)
* Git

### Running the Backend

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a Python virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: .\venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Run the development server:
   ```bash
   python main.py
   ```

The backend server will launch on `http://0.0.0.0:10000` (or the port specified in environment variables).

### Running the Frontend

1. Ensure the backend server is running and accessible.
2. Navigate to the root directory of the Flutter project.
3. Install the dependencies:
   ```bash
   flutter pub get
   ```
4. Configure your `.env` file at the root directory with your Gemini API key and backend URL:
   ```env
   GEMINI_API_KEY=your_api_key_here
   BACKEND_WS_URL=ws://10.0.2.2:10000/ws/detect
   ```
5. Run the application:
   ```bash
   flutter run
   ```

---

## Project Profiles

* GitHub: https://github.com/itzsaad09/
* LinkedIn: https://www.linkedin.com/in/itzsaad09/
