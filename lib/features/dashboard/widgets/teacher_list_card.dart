import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TeacherListCard extends StatelessWidget {
  final List<Map<String, dynamic>> teachers;
  final VoidCallback? onAddTap;

  const TeacherListCard({super.key, required this.teachers, this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Teacher List',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                onPressed: onAddTap,
                icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6366F1), size: 20),
                tooltip: 'Add Teacher',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: 600, // Fixed width for horizontal scrolling on narrow screens
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(2),
                        4: FlexColumnWidth(0.5),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _buildHeaderCell('Name'),
                            _buildHeaderCell('Class'),
                            _buildHeaderCell('Subject'),
                            _buildHeaderCell('Email'),
                            _buildHeaderCell('Action'),
                          ],
                        ),
                        ...teachers.map((teacher) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: NetworkImage(teacher['avatar'] ?? 'https://i.pravatar.cc/150?u=${teacher['name']}'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      teacher['name'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildCell(teacher['class'] ?? ''),
                            _buildCell(teacher['subject'] ?? ''),
                            _buildCell(teacher['email'] ?? ''),
                            const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 18),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}
