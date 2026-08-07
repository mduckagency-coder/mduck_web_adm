import "package:flutter/material.dart";
import "event_category.dart";
import "event_participant.dart";

TimeOfDay? _parseTime(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(":");
  if (parts.length < 2) return null;
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String? timeOfDayToSql(TimeOfDay? time) {
  if (time == null) return null;
  final h = time.hour.toString().padLeft(2, "0");
  final m = time.minute.toString().padLeft(2, "0");
  return h + ":" + m + ":00";
}

class CalendarEvent {
  final String id;
  final String categoryId;
  final EventCategory? category;
  final String title;
  final String? description;
  final DateTime eventDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool allDay;
  final String? location;
  final String? meetingLink;
  final String? notes;
  final String priority;
  final String status;
  final String scope;
  final String visibility;
  final String? createdBy;
  final List<EventParticipant> participants;
  final bool showInAgencyCalendar;
  final bool showInApp;
  final String? colorOverride;

  const CalendarEvent({
    required this.id,
    required this.categoryId,
    this.category,
    required this.title,
    this.description,
    required this.eventDate,
    this.startTime,
    this.endTime,
    required this.allDay,
    this.location,
    this.meetingLink,
    this.notes,
    required this.priority,
    required this.status,
    this.scope = "agencia",
    this.visibility = "equipe",
    this.createdBy,
    this.participants = const [],
    this.showInAgencyCalendar = true,
    this.showInApp = false,
    this.colorOverride,
  });

  List<EventParticipant> get streamerParticipants => participants.where((p) => p.isStreamer).toList();
  List<EventParticipant> get gestorParticipants => participants.where((p) => p.isGestor).toList();

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    final categoryMap = map["event_categories"] as Map<String, dynamic>?;
    final participantsList = (map["calendar_event_participants"] as List?) ?? const [];
    return CalendarEvent(
      id: map["id"] as String,
      categoryId: map["category_id"] as String,
      category: categoryMap != null ? EventCategory.fromMap(categoryMap) : null,
      title: map["title"] as String,
      description: map["description"] as String?,
      eventDate: DateTime.parse(map["event_date"] as String),
      startTime: _parseTime(map["start_time"] as String?),
      endTime: _parseTime(map["end_time"] as String?),
      allDay: map["all_day"] as bool? ?? false,
      location: map["location"] as String?,
      meetingLink: map["meeting_link"] as String?,
      notes: map["notes"] as String?,
      priority: map["priority"] as String? ?? "normal",
      status: map["status"] as String? ?? "agendado",
      scope: map["scope"] as String? ?? "agencia",
      visibility: map["visibility"] as String? ?? "equipe",
      createdBy: map["created_by"] as String?,
      participants: participantsList.map((p) => EventParticipant.fromMap(p as Map<String, dynamic>)).toList(),
      showInAgencyCalendar: map["show_in_agency_calendar"] as bool? ?? true,
      showInApp: map["show_in_app"] as bool? ?? false,
      colorOverride: map["color_override"] as String?,
    );
  }
}
