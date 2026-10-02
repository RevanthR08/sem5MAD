class ApiConstants {
  // FastAPI Backend Host. Override at build time for a phone on Wi-Fi:
  //   flutter run --dart-define=API_BASE_URL=http://<PC-LAN-IP>:8000/api/v1
  // The default works on web, desktop, and on a USB phone after `adb reverse tcp:8000 tcp:8000`.
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000/api/v1');

  // Supabase Details
  static const String supabaseUrl = 'https://eecebjjpaxktrdsqkuoh.supabase.co';
  static const String supabaseKey = 'sb_publishable_pcLbJ9W0P_4NZhBsv8gx7A_TzTt_RSm';
}
