import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';
import 'auth_service.dart';

/// Service for syncing sessions with Firebase Cloud Firestore
class CloudSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;
  
  CloudSessionService(this._authService);
  
  /// Get the sessions collection reference for current user
  CollectionReference<Map<String, dynamic>>? get _sessionsCollection {
    final userId = _authService.userId;
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('sessions');
  }
  
  /// Check if user is logged in
  bool get isLoggedIn => _authService.isLoggedIn;
  
  /// Save a session to the cloud
  /// Uses sessionNumber + timestamp as unique identifier
  Future<bool> saveSession(SessionModel session) async {
    if (!isLoggedIn || _sessionsCollection == null) {
      print('⏭️ Skipping cloud save: not logged in');
      return false;
    }
    
    try {
      // Create a unique document ID based on session number and timestamp
      final docId = '${session.sessionNumber}_${session.timestamp.millisecondsSinceEpoch}';
      
      print('☁️ Uploading session ${session.sessionNumber} to Firestore...');
      await _sessionsCollection!.doc(docId).set({
        ...session.toJson(),
        'uploadedAt': FieldValue.serverTimestamp(),
        'userId': _authService.userId,
      }).timeout(const Duration(seconds: 10));
      
      print('✅ Session ${session.sessionNumber} saved to cloud');
      return true;
    } catch (e) {
      print('❌ Failed to save session to cloud: $e');
      return false;
    }
  }
  
  /// Fetch all sessions from the cloud for current user
  Future<List<SessionModel>> fetchSessions() async {
    if (!isLoggedIn || _sessionsCollection == null) {
      print('⏭️ Cannot fetch from cloud: not logged in');
      return [];
    }
    
    try {
      print('☁️ Querying Firestore for sessions...');
      final snapshot = await _sessionsCollection!
          .orderBy('timestamp', descending: true)
          .get()
          .timeout(const Duration(seconds: 10));
      
      final sessions = snapshot.docs.map((doc) {
        return SessionModel.fromJson(doc.data());
      }).toList();
      
      print('✅ Fetched ${sessions.length} sessions from cloud');
      return sessions;
    } catch (e) {
      print('❌ Failed to fetch sessions from cloud: $e');
      return [];
    }
  }
  
  /// Delete a session from the cloud
  Future<bool> deleteSession(SessionModel session) async {
    if (!isLoggedIn || _sessionsCollection == null) {
      print('❌ Cannot delete from cloud: not logged in');
      return false;
    }
    
    try {
      // Find and delete the document
      final docId = '${session.sessionNumber}_${session.timestamp.millisecondsSinceEpoch}';
      await _sessionsCollection!.doc(docId).delete();
      
      print('✅ Session ${session.sessionNumber} deleted from cloud');
      return true;
    } catch (e) {
      print('❌ Failed to delete session from cloud: $e');
      return false;
    }
  }
  
  /// Sync local sessions to cloud (upload all)
  Future<int> uploadAllSessions(List<SessionModel> sessions) async {
    if (!isLoggedIn) return 0;
    
    int uploaded = 0;
    for (final session in sessions) {
      if (await saveSession(session)) {
        uploaded++;
      }
    }
    
    print('✅ Uploaded $uploaded/${sessions.length} sessions to cloud');
    return uploaded;
  }
  
  /// Check if a session already exists in cloud
  Future<bool> sessionExists(SessionModel session) async {
    if (!isLoggedIn || _sessionsCollection == null) return false;
    
    try {
      final docId = '${session.sessionNumber}_${session.timestamp.millisecondsSinceEpoch}';
      final doc = await _sessionsCollection!.doc(docId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}
