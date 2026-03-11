import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // for formatting timestamps

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  List<Map<String, dynamic>> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  Future<void> fetchLogs() async {
    setState(() => isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('audit_logs')
          .select()
          .order('timestamp', ascending: false);

      // response is already List<Map<String,dynamic>>
      setState(() {
        logs = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      setState(() => isLoading = false);
    }
  }

  String formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
      body: RefreshIndicator(
        onRefresh: fetchLogs,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : logs.isEmpty
            ? const Center(
                child: Text(
                  'No audit logs available.',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        log['action'] ?? 'Unknown action',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (log['performed_by'] != null)
                            Text('By: ${log['performed_by']}'),
                          if (log['timestamp'] != null)
                            Text('Time: ${formatTimestamp(log['timestamp'])}'),
                          if (log['details'] != null)
                            Text('Details: ${log['details']}'),
                        ],
                      ),
                      leading: const Icon(Icons.history),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
