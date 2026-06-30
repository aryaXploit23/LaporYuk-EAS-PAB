import '../../data/models/report_model.dart';

abstract class ReportsState {}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  final List<ReportModel> reports;
  final String? message; // Untuk pesan notifikasi/offline warning

  ReportsLoaded(this.reports, {this.message});
}

class ReportsError extends ReportsState {
  final String message;
  ReportsError(this.message);
}
