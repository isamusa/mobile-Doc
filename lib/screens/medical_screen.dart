import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';

class MedicalScreen extends StatelessWidget {
  const MedicalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Medical Hub"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Isa Musa",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900)),
                  const SizedBox(height: 4),
                  const Text("Genotype: AA  |  Blood Group: O+",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  const Text("Latest Diagnosis:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text(
                      "Patient reported recurrent fever and bitter taste. Suspected Malaria.",
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text("Actions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Generate Slip Button
            InkWell(
              onTap: () => _generateAndPrintPdf(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.1), blurRadius: 10)
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.print, color: Colors.teal),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Generate Lab Request Slip",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("For Malaria (MP) & Widal Test",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PDF Generation and Printing
  Future<void> _generateAndPrintPdf(BuildContext context) async {
    final pdf = pw.Document();

    // Create the PDF Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MOBILE DOC CLINIC',
                        style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal)),
                    pw.Text('LAB REQUEST FORM',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Patient Details
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(children: [
                      pw.Text('Patient Name: '),
                      pw.Text('Isa Musa',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                    ]),
                    pw.SizedBox(height: 5),
                    pw.Row(children: [
                      pw.Text('Date: '),
                      pw.Text(DateTime.now().toString().split(' ')[0])
                    ]),
                    pw.SizedBox(height: 5),
                    pw.Row(children: [
                      pw.Text('Ref ID: '),
                      pw.Text('#MD-882190',
                          style: pw.TextStyle(font: pw.Font.courier()))
                    ]),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Tests Requested
              pw.Text('REQUESTED INVESTIGATIONS:',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              pw.Bullet(text: 'Malaria Parasite (MP) - Microscopy'),
              pw.SizedBox(height: 5),
              pw.Bullet(text: 'Widal Reaction Test (Typhoid)'),
              pw.SizedBox(height: 5),
              pw.Bullet(text: 'Full Blood Count (FBC)'),

              pw.SizedBox(height: 50),

              // Footer / Signature
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Signed:',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 20),
                      pw.Container(
                          width: 100,
                          decoration: pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide()))),
                      pw.Text('Dr. Mobile Doc (AI Consultant)',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    data: 'IsaMusa-MD-8821',
                    width: 60,
                    height: 60,
                    barcode: pw.Barcode.qrCode(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Show Print/Share Dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
