import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickActionsGrid extends StatelessWidget {
  final Function(String action)? onActionTap;

  const QuickActionsGrid({super.key, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 24),
            _buildActionGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    final actions = [
      _ActionItem(Icons.person_add_rounded, 'Add Student', const Color(0xFF488B80)),
      _ActionItem(Icons.school_rounded, '+ Add Teacher', const Color(0xFFE27396)),
      _ActionItem(Icons.monetization_on_rounded, 'Record Payment', const Color(0xFF5B7DB1)),
      _ActionItem(Icons.description_rounded, 'Generate Invoice', const Color(0xFFEA9E44)),
      _ActionItem(Icons.send_rounded, 'Send Fee Reminder', const Color(0xFFF97316)),
      _ActionItem(Icons.campaign_rounded, 'Send Announcement', const Color(0xFF8B5CF6)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 3,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: () => onActionTap?.call(action.label),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  action.label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  _ActionItem(this.icon, this.label, this.color);
}

class StudentOverviewCard extends StatelessWidget {
  final int total;
  final int boys;
  final int girls;
  final int defaulters;
  final String currentClass;
  final VoidCallback? onClassTap;
  final VoidCallback? onViewClassList;
  final VoidCallback? onMoreTap;

  const StudentOverviewCard({
    super.key,
    required this.total,
    required this.boys,
    required this.girls,
    required this.defaulters,
    this.currentClass = 'Class 9',
    this.onClassTap,
    this.onViewClassList,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Students ',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    InkWell(
                      onTap: onClassTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '($currentClass)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF475569)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onMoreTap,
                  icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Total: $total',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Boys: $boys  |  Girls: $girls',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Fee defaulters: $defaulters ',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEAB308), size: 18),
                  ],
                ),
                ElevatedButton(
                  onPressed: onViewClassList,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B7DB1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View Class List',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
