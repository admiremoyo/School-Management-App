import 'package:flutter/material.dart';
import '../../data/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../data/services/payment_service.dart';

class RegistrationPage extends StatefulWidget {
  final AppDatabase db;
  final Student? student; // Null for registration, non-null for editing
  final String? initialClassName;

  const RegistrationPage({
    super.key,
    required this.db,
    this.student,
    this.initialClassName,
  });

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _guardianController;
  late TextEditingController _dateController;
  late TextEditingController _classNameController;
  final _feeController = TextEditingController();
  late TextEditingController _userIdController;
  late TextEditingController _emailController;
  DateTime? _selectedDate;

  bool get isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student?.name);
    _guardianController = TextEditingController(text: widget.student?.guardianContact);
    _classNameController = TextEditingController(text: widget.initialClassName);
    _selectedDate = widget.student?.dateOfBirth;
    _dateController = TextEditingController(
      text: _selectedDate == null ? '' : '${_selectedDate!.toLocal()}'.split(' ')[0],
    );
    _userIdController = TextEditingController(text: widget.student?.userId);
    _emailController = TextEditingController(text: widget.student?.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _guardianController.dispose();
    _dateController.dispose();
    _classNameController.dispose();
    _feeController.dispose();
    _userIdController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Date of Birth')),
      );
      return;
    }

    try {
      final String studentId = widget.student?.id ?? const Uuid().v4();
      final String schoolId = widget.student?.schoolId ?? widget.db.schoolId;

      // 1. Handle Class (Find existing or create new)
      final className = _classNameController.text.trim();
      var schoolClass = await (widget.db.select(widget.db.classes)
            ..where((t) => t.name.equals(className)))
          .getSingleOrNull();

      if (schoolClass == null) {
        final classId = const Uuid().v4();
        await widget.db.into(widget.db.classes).insert(
              ClassesCompanion.insert(
                id: classId,
                schoolId: schoolId,
                name: className,
                syncStatus: const drift.Value('PENDING'),
              ),
            );
        schoolClass = await (widget.db.select(widget.db.classes)
              ..where((t) => t.id.equals(classId)))
            .getSingle();
      }

      // 2. Save/Update Student
      if (isEditing) {
        await (widget.db.update(widget.db.students)..where((t) => t.id.equals(studentId))).write(
          StudentsCompanion(
            name: drift.Value(_nameController.text),
            dateOfBirth: drift.Value(_selectedDate!),
            guardianContact: drift.Value(_guardianController.text),
            classId: drift.Value(schoolClass.id),
            userId: drift.Value(_userIdController.text.trim().isEmpty ? null : _userIdController.text.trim()),
            email: drift.Value(_emailController.text.trim().isEmpty ? null : _emailController.text.trim()),
            syncStatus: const drift.Value('PENDING'),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
      } else {
        await widget.db.into(widget.db.students).insert(
              StudentsCompanion.insert(
                id: studentId,
                schoolId: schoolId,
                name: _nameController.text,
                dateOfBirth: _selectedDate!,
                guardianContact: drift.Value(_guardianController.text),
                classId: schoolClass.id,
                userId: drift.Value(_userIdController.text.trim().isEmpty ? null : _userIdController.text.trim()),
                email: drift.Value(_emailController.text.trim().isEmpty ? null : _emailController.text.trim()),
                syncStatus: const drift.Value('PENDING'),
              ),
            );

        // 3. Record Fee if provided (only for new registrations)
        final feeAmount = double.tryParse(_feeController.text);
        if (feeAmount != null && feeAmount > 0) {
          await PaymentService(widget.db).recordPayment(
            studentId: studentId,
            amount: feeAmount,
            paymentDate: DateTime.now(),
            paymentMethod: 'Cash',
            recordedBy: widget.db.userId,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Student updated!' : 'Student registered!')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Student' : 'Register Student'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _classNameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name (e.g. Grade 1)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.class_),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _guardianController,
                decoration: const InputDecoration(
                  labelText: 'Guardian Contact',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime(2015),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _dateController.text = '${picked.toLocal()}'.split(' ')[0];
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Student Email (for app login)',
                  helperText: 'Student must use this email to sign up',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _userIdController,
                decoration: const InputDecoration(
                  labelText: 'Alternative: Student User ID',
                  helperText: 'Only use if they already have an account',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              if (!isEditing) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _feeController,
                  decoration: const InputDecoration(
                    labelText: 'Initial Fee Payment (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money),
                    suffixText: r'$',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveStudent,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isEditing ? 'UPDATE STUDENT' : 'REGISTER STUDENT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

