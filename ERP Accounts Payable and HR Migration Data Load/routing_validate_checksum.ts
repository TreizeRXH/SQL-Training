/**
 * ERP Migration — Routing Number Script 2 of 2
 * Validates: All existing routing numbers against ABA mod-10 checksum algorithm
 *
 * ABA Checksum Formula:
 *   3(d1+d4+d7) + 7(d2+d5+d8) + 1(d3+d6+d9) must be divisible by 10
 *   where d1-d9 are the individual digits of the 9-digit routing number
 *
 * Valid routing numbers: Flagged green (validated)
 * Invalid routing numbers: Flagged red, logged for manual review
 * Skips: blanks and 999999999 placeholders inserted by routing_fix_blanks.ts
 *
 * Run after routing_fix_blanks.ts
 */

function main(workbook: ExcelScript.Workbook) {

  const sheet        = workbook.getWorksheet("Vendors");
  const log          = getOrCreateLog(workbook);
  let   logRow       = nextLogRow(log);
  const ts           = new Date().toISOString().replace("T", " ").substring(0, 19);
  const lastRow      = sheet.getUsedRange().getRowCount();
  let   validCount   = 0;
  let   invalidCount = 0;

  for (let i = 1; i < lastRow; i++) {
    const cell = sheet.getCell(i, 14);   // Column O — Bank Routing #
    const val  = String(cell.getValue() ?? "").trim();

    // skip blanks — handled by routing_fix_blanks.ts
    if (val === "") continue;
    // skip known placeholder — deliberately invalid, not a validation target
    if (val === "999999999") continue;

    if (isValidABA(val)) {
      validCount++;
      cell.getFormat().getFill().setColor("EAFAF1");   // light green = validated
    } else {
      invalidCount++;
      cell.getFormat().getFill().setColor("FF9999");   // red = fails checksum
      writeLog(log, logRow, invalidCount, ts, i + 1, val,
               "[not changed]", "Fails ABA mod-10 checksum — manual review required",
               "O", "Bank Routing #");
      logRow++;
    }
  }

  log.getUsedRange().getFormat().autofitColumns();
  console.log(`Routing validation complete. Valid: ${validCount}. Failed checksum: ${invalidCount}.`);
}

/**
 * ABA mod-10 checksum validation.
 *
 * Routing numbers must be exactly 9 digits.
 * The weighted sum formula: 3(d1+d4+d7) + 7(d2+d5+d8) + 1(d3+d6+d9)
 * must produce a result divisible by 10 (i.e. result % 10 === 0).
 *
 * Digit 9 is the check digit — calculated from the first 8 digits
 * specifically to make the checksum pass.
 *
 * Example — Chase routing 021000021:
 *   3(0+0+0) + 7(2+0+2) + 1(1+0+1) = 0 + 28 + 2 = 30 → 30 % 10 = 0 ✓
 */
function isValidABA(routing: string): boolean {
  if (!/^\d{9}$/.test(routing)) return false;
  const d = routing.split("").map(Number);
  const checksum = (3 * (d[0] + d[3] + d[6]))
                 + (7 * (d[1] + d[4] + d[7]))
                 + (1 * (d[2] + d[5] + d[8]));
  return checksum % 10 === 0;
}

function getOrCreateLog(workbook: ExcelScript.Workbook): ExcelScript.Worksheet {
  let log = workbook.getWorksheet("Migration Defect Log");
  if (!log) {
    log = workbook.addWorksheet("Migration Defect Log");
    const headers = ["Log ID", "Timestamp", "Sheet", "Row #", "Column",
                     "Original Value", "New Value", "Defect Type", "Actioned By"];
    headers.forEach((h, i) => {
      const cell = log.getCell(0, i);
      cell.setValue(h);
      cell.getFormat().getFill().setColor("1F4E79");
      cell.getFormat().getFont().setColor("FFFFFF");
      cell.getFormat().getFont().setBold(true);
    });
  }
  return log;
}

function nextLogRow(log: ExcelScript.Worksheet): number {
  const used = log.getUsedRange();
  return used ? used.getRowCount() : 1;
}

function writeLog(log: ExcelScript.Worksheet, logRow: number, logID: number,
                  ts: string, sourceRow: number, originalVal: string,
                  newVal: string, defectType: string,
                  colLetter: string, colName: string): void {
  const entry = [logID, ts, "Vendors", sourceRow, colName,
                 originalVal, newVal, defectType, "Migration Script"];
  entry.forEach((v, col) => log.getCell(logRow, col).setValue(v));
  if (logRow % 2 === 0) {
    for (let c = 0; c < entry.length; c++) {
      log.getCell(logRow, c).getFormat().getFill().setColor("D6E4F0");
    }
  }
}
