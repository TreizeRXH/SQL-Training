/**
 * ERP Migration — Routing Number Script 1 of 2
 * Fixes: Missing routing numbers on active vendors (Column O)
 * Replaces with: 999999999
 *   - Deliberately and obviously invalid — stands out in any query or report
 *   - No payment could ever process against this value
 *   - Preferred over a "valid-looking" placeholder that could cause confusion
 * Flags cell: Yellow (requires client to provide real routing number)
 * Logs: Every change written to Migration Defect Log sheet
 *
 * Run before routing_validate_checksum.ts
 */

function main(workbook: ExcelScript.Workbook) {

  const sheet         = workbook.getWorksheet("Vendors");
  const log           = getOrCreateLog(workbook);
  let   logRow        = nextLogRow(log);
  const ts            = new Date().toISOString().replace("T", " ").substring(0, 19);
  const lastRow       = sheet.getUsedRange().getRowCount();
  let   fixedCount    = 0;

  const DUMMY_ROUTING = "999999999";   // deliberately invalid placeholder

  for (let i = 1; i < lastRow; i++) {
    const cell = sheet.getCell(i, 14);   // Column O — Bank Routing #
    const val  = String(cell.getValue() ?? "").trim();

    if (val === "") {
      fixedCount++;
      cell.setValue(DUMMY_ROUTING);
      cell.getFormat().getFill().setColor("FFE699");   // yellow
      writeLog(log, logRow, fixedCount, ts, i + 1, "[blank]", DUMMY_ROUTING,
               "Missing / null", "O", "Bank Routing #");
      logRow++;
    }
  }

  log.getUsedRange().getFormat().autofitColumns();
  console.log(`Blank Routing # fixed: ${fixedCount}`);
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
