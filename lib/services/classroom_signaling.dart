import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClassroomSignal {
  final String id;
  final String classroomId;
  final String senderId;
  final String receiverId;
  final String type; // 'offer' | 'answer' | 'candidate' | 'join' | 'leave'
  final String? sdp;
  final Map<String, dynamic>? candidate;

  ClassroomSignal({
    required this.id,
    required this.classroomId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    this.sdp,
    this.candidate,
  });

  factory ClassroomSignal.fromMap(Map<String, dynamic> m) {
    return ClassroomSignal(
      id: m['id'] as String,
      classroomId: m['classroom_id'] as String,
      senderId: m['sender_id'] as String,
      receiverId: m['receiver_id'] as String,
      type: m['type'] as String,
      sdp: m['sdp'] as String?,
      candidate: m['candidate'] is Map
          ? Map<String, dynamic>.from(m['candidate'])
          : null,
    );
  }
}

class ClassroomSignaling {
  final SupabaseClient supabase;
  RealtimeChannel? _channel;
  final _stream = StreamController<ClassroomSignal>.broadcast();

  ClassroomSignaling(this.supabase);

  // ---------- Realtime сигналы звонка ----------
  Stream<ClassroomSignal> subscribe(String classroomId) {
    _channel?.unsubscribe();
    _channel = supabase
        .channel('classroom_signals:$classroomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'classroom_signals',
          callback: (payload) {
            final rec = payload.newRecord as Map<String, dynamic>;
            if (rec['classroom_id'] == classroomId) {
              _stream.add(ClassroomSignal.fromMap(rec));
            }
          },
        )
        .subscribe();
    return _stream.stream;
  }

  Future<String> createClassroom({
    required String schoolId,
    required String teacherId,
  }) async {
    final res = await supabase
        .from('classrooms')
        .insert({'school_id': schoolId, 'teacher_id': teacherId})
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<void> sendOffer({
    required String classroomId,
    required String from,
    required String to,
    required String sdp,
  }) async {
    await supabase.from('classroom_signals').insert({
      'classroom_id': classroomId,
      'sender_id': from,
      'receiver_id': to,
      'type': 'offer',
      'sdp': sdp,
    });
  }

  Future<void> sendAnswer({
    required String classroomId,
    required String from,
    required String to,
    required String sdp,
  }) async {
    await supabase.from('classroom_signals').insert({
      'classroom_id': classroomId,
      'sender_id': from,
      'receiver_id': to,
      'type': 'answer',
      'sdp': sdp,
    });
  }

  Future<void> sendCandidate({
    required String classroomId,
    required String from,
    required String to,
    required Map<String, dynamic> candidate,
  }) async {
    await supabase.from('classroom_signals').insert({
      'classroom_id': classroomId,
      'sender_id': from,
      'receiver_id': to,
      'type': 'candidate',
      'candidate': candidate,
    });
  }

  Future<void> sendJoin({
    required String classroomId,
    required String studentId,
    required String teacherId,
  }) async {
    await supabase.from('classroom_signals').insert({
      'classroom_id': classroomId,
      'sender_id': studentId,
      'receiver_id': teacherId,
      'type': 'join',
    });
  }

  Future<void> sendLeave({
    required String classroomId,
    required String from,
    required String to,
  }) async {
    await supabase.from('classroom_signals').insert({
      'classroom_id': classroomId,
      'sender_id': from,
      'receiver_id': to,
      'type': 'leave',
    });
  }

  // ---------- Публикация/чтение активного урока ----------
  Future<void> setActiveClassroom({
    required String schoolId,
    required String classroomId,
    required String teacherId,
  }) async {
    await supabase.from('active_classrooms').upsert({
      'school_id': schoolId,
      'classroom_id': classroomId,
      'teacher_id': teacherId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<({String classroomId, String teacherId})?> getActiveClassroom({
    required String schoolId,
  }) async {
    final res = await supabase
        .from('active_classrooms')
        .select('classroom_id, teacher_id')
        .eq('school_id', schoolId)
        .maybeSingle();

    if (res == null) return null;
    return (
      classroomId: res['classroom_id'] as String,
      teacherId: res['teacher_id'] as String
    );
  }

  Future<void> clearActiveClassroom({required String schoolId}) async {
    await supabase.from('active_classrooms').delete().eq('school_id', schoolId);
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    await _stream.close();
  }
}
