/**
 * ERP Migration — Tax ID Cleansing Script 4 of 4
 * Fixes: EINs stored as 9 consecutive digits (missing dash)
 * Action: Inserts dash after position 2 (e.g. 123456789 → 12-3456789)
 * Flags cell: Green (remediated automatically)
 * Unknown formats: Flagged red for manual review — value not modified
 * Logs: Every change written to Migration Defect Log sheet
 *
 * Skips: blanks, 99-MIGR placeholders, N/A, PENDING, already-correct XX-XXXXXXX
 */

function main(workbook: ExcelScript.Workbook) {

  const sheet        = workbook.getWorksheet("Vendors");
  const log          = getOrCreateLog(workbook);
  let   logRow       = nextLogRow(log);
  const ts           = new Date().toISOString().replace("T", " ").substring(0, 19);
  const lastRow      = sheet.getUsedRange().getRowCount();
  let   fixedCount   = 0;
  let   skippedCount = 0;

  const validEIN  = /^\d{2}-\d{7}$/;   // already correct
  const noDashEIN = /^\d{9}$/;          // 9 digits, safe to fix

  for (let i = 1; i < lastRow; i++) {
    const cell = sheet.getCell(i, 3);   // Column D — Tax ID (EIN)
    const raw  = cell.getValue();
    const val  = String(raw ?? "").trim();

    // skip anything handled by scripts 1-3
    if (val === "")                      continue;
    if (val.startsWith("99-MIGR"))       continue;
    if (val.toUpperCase() === "N/A")     continue;
    if (val.toUpperCase() === "PENDING") continue;

    // already correct — leave it alone
    if (validEIN.test(val))              continue;

    if (noDashEIN.test(val)) {
      // safe to fix — insert dash after position 2
      fixedCount++;
      const fixed = `${val.substring(0, 2)}-${val.substring(2)}`;
      cell.setValue(fixed);
      cell.getFormat().getFill().setColor("EAFAF1");   // light green = remediated
      writeLog(log, logRow, fixedCount, ts, i + 1, val, fixed,
               "Missing dash — inserted at position 2", "D", "Tax ID (EIN)");
      logRow++;

    } else {
      // unknown format — flag red, do not modify
      skippedCount++;
      cell.getFormat().getFill().setColor("FF9999");   // red = manual review required
      writeLog(log, logRow, fixedCount + skippedCount, ts, i + 1, val,
               "[not changed]", "Unrecognized format — manual review required",
               "D", "Tax ID (EIN)");
      logRow++;
    }
  }

  log.getUsedRange().getFormat().autofitColumns();
  console.log(`EIN dash fix complete. Fixed: ${fixedCount}. Flagged for review: ${skippedCount}.`);
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
