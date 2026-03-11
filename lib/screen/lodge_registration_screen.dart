import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class LodgeRegistrationScreen extends StatefulWidget {
  const LodgeRegistrationScreen({super.key});

  @override
  State<LodgeRegistrationScreen> createState() =>
      _LodgeRegistrationScreenState();
}

class _LodgeRegistrationScreenState extends State<LodgeRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  final TextEditingController lodgeName = TextEditingController();
  final TextEditingController lodgeNumber = TextEditingController();
  final TextEditingController city = TextEditingController();
  String? selectedProvince;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool isLoading = false;

  final List<String> provinces = [
    "Abra",
    "Agusan del Norte",
    "Agusan del Sur",
    "Aklan",
    "Albay",
    "Antique",
    "Apayao",
    "Aurora",
    "Basilan",
    "Bataan",
    "Batanes",
    "Batangas",
    "Benguet",
    "Biliran",
    "Bohol",
    "Bukidnon",
    "Bulacan",
    "Cagayan",
    "Camarines Norte",
    "Camarines Sur",
    "Camiguin",
    "Capiz",
    "Catanduanes",
    "Cavite",
    "Cebu",
    "Cotabato",
    "Davao de Oro",
    "Davao del Norte",
    "Davao del Sur",
    "Davao Occidental",
    "Davao Oriental",
    "Dinagat Islands",
    "Eastern Samar",
    "Guimaras",
    "Ifugao",
    "Ilocos Norte",
    "Ilocos Sur",
    "Iloilo",
    "Isabela",
    "Kalinga",
    "La Union",
    "Laguna",
    "Lanao del Norte",
    "Lanao del Sur",
    "Leyte",
    "Maguindanao del Norte",
    "Maguindanao del Sur",
    "Marinduque",
    "Masbate",
    "Misamis Occidental",
    "Misamis Oriental",
    "Mountain Province",
    "Negros Occidental",
    "Negros Oriental",
    "Northern Samar",
    "Nueva Ecija",
    "Nueva Vizcaya",
    "Occidental Mindoro",
    "Oriental Mindoro",
    "Palawan",
    "Pampanga",
    "Pangasinan",
    "Quezon",
    "Quirino",
    "Rizal",
    "Romblon",
    "Samar",
    "Sarangani",
    "Siquijor",
    "Sorsogon",
    "South Cotabato",
    "Southern Leyte",
    "Sultan Kudarat",
    "Sulu",
    "Surigao del Norte",
    "Surigao del Sur",
    "Tarlac",
    "Tawi-Tawi",
    "Zambales",
    "Zamboanga del Norte",
    "Zamboanga del Sur",
    "Zamboanga Sibugay",
  ];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    lodgeName.dispose();
    lodgeNumber.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (lodgeName.text.isEmpty ||
        lodgeNumber.text.isEmpty ||
        city.text.isEmpty ||
        selectedProvince == null) {
      _showError("Please fill in all required fields.");
      return;
    }

    if (lodgeNumber.text.length != 3 ||
        int.tryParse(lodgeNumber.text) == null) {
      _showError("Lodge Number must be exactly 3 digits.");
      return;
    }

    final lodgeNum = int.parse(lodgeNumber.text);

    try {
      setState(() => isLoading = true);

      final user = supabase.auth.currentUser;
      if (user == null) {
        _showError("User not authenticated.");
        return;
      }

      await supabase.from('req_lodges').insert({
        'lodge_number': lodgeNum,
        'lodge_name': lodgeName.text.trim(),
        'city': city.text.trim(),
        'province': selectedProvince,
        'requested_by': user.id,
        'status': 'PENDING',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .toIso8601String(),
      });

      if (!mounted) return;

      _showSuccess("Lodge request submitted successfully.");

      Navigator.pop(context);
    } catch (e) {
      _showError("Registration failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Lodge Registration")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      "Register Lodge",
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: lodgeNumber,
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            decoration: const InputDecoration(
                              labelText: "No.",
                              counterText: "",
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: lodgeName,
                            decoration: const InputDecoration(
                              labelText: "Lodge Name",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: city,
                      decoration: const InputDecoration(labelText: "City"),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedProvince,
                      decoration: const InputDecoration(labelText: "Province"),
                      items: provinces
                          .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => selectedProvince = val),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitRegistration,
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Submit Registration",
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
