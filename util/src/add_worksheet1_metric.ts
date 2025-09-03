import Excel from "exceljs";
import fs from "fs";

async function appendCsvAsColumns(xlsxPath: string, csvPath: string, outPath: string) {
  const workbook = new Excel.Workbook();
  await workbook.xlsx.readFile(xlsxPath);
  const sheet = workbook.worksheets[0]; // first sheet

  // read CSV into rows
  const csvRows = fs
    .readFileSync(csvPath, "utf-8")
    .trim()
    .split("\n")
    .map(r => r.split(","));

  // sanity: match row count
  if (csvRows.length !== sheet.rowCount) {
    throw new Error(`Row mismatch: sheet has ${sheet.rowCount}, csv has ${csvRows.length}`);
  }

  // append CSV values as new columns
  csvRows.forEach((csvRow, i) => {
    const row = sheet.getRow(i + 1); // exceljs rows are 1-based
    csvRow.forEach(val => row.values.push(val));
    row.commit();
  });

  await workbook.xlsx.writeFile(outPath);
}

// Example usage
appendCsvAsColumns("file.xlsx", "data.csv", "out.xlsx")
  .then(() => console.log("Done"))
  .catch(err => console.error(err));
