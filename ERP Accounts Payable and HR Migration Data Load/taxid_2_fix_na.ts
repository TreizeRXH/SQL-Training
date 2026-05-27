/**
 * ERP Migration — Tax ID Cleansing Script 2 of 4
 * Fixes: Tax IDs containing "N/A"
 * Replaces with: 99-MIGR#### placeholder
 * Flags cell: Yellow (requires client to provide real EIN)
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
    const cell = sheet.getCell(i, 3);   // Column D — Tax ID (EIN)
    const val  = String(cell.getValue() ?? "").trim().toUpperCase();

    if (val === "N/A") {
      fixedCount++;
      const placeholder = `99-MIGR${String(i).padStart(4, "0")}`;
      cell.setValue(placeholder);
      cell.getFormat().getFill().setColor("FFE699");   // yellow
      writeLog(log, logRow, fixedCount, ts, i + 1, "N/A", placeholder,
               "Non-value placeholder (N/A)", "D", "Tax ID (EIN)");
      logRow++;
    }
  }

  log.getUsedRange().getFormat().autofitColumns();
  console.log(`N/A Tax IDs fixed: ${fixedCount}`);
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
