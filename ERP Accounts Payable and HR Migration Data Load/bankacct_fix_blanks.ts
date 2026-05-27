/**
 * ERP Migration — Bank Account Cleansing Script 1 of 1
 * Fixes: Missing bank account numbers on active vendors (Column N)
 * Replaces with: 000-MIGR-#### placeholder
 *   - 000 prefix is not a valid bank prefix in any US routing schema
 *   - Clearly identifiable as a migration placeholder in any query or report
 * Flags cell: Yellow (requires client to provide real account number)
 * Logs: Every change written to Migration Defect Log sheet
 */

function main(workbook: ExcelScript.Workbook) {

  const sheet      = workbook.getWorksheet("Vendors");
  const log        = getOrCreateLog(workbook);
  let   logRow     = nextLogRow(log);
  const ts         = new Date().toISOString().replace("T", " ").substring(0, 19);
  const lastRow    = sheet.getUsedRange().getRowCount();
  let   fixedCount = 0;

  for (let i = 1; i < lastRow; i++) {
    const cell = sheet.getCell(i, 13);   // Column N — Bank Account #
    const val  = String(cell.getValue() ?? "").trim();

    if (val === "") {
      fixedCount++;
      const placeholder = `000-MIGR-${String(i).padStart(4, "0")}`;
      cell.setValue(placeholder);
      cell.getFormat().getFill().setColor("FFE699");   // yellow
      writeLog(log, logRow, fixedCount, ts, i + 1, "[blank]", placeholder,
               "Missing / null", "N", "Bank Account #");
      logRow++;
    }
  }

  log.getUsedRange().getFormat().autofitColumns();
  console.log(`Blank Bank Account # fixed: ${fixedCount}`);
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
