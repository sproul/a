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


  // append CSV values as new columns
  csvRows.forEach((csvRow, i) => {
    const row = sheet.getRow(i + 1); // exceljs rows are 1-based
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-ignore
    row.values = [...(row.values as Excel.CellValue[]), ...csvRow];
    row.commit();
  });

  await workbook.xlsx.writeFile(outPath);
}

const [xlsxPath, csvPath, outPath] = process.argv.slice(2);

if (!xlsxPath || !csvPath || !outPath) {
  console.error("Usage: ts-node <script> <xlsxPath> <csvPath> <outPath>");
  process.exit(1);
}

appendCsvAsColumns(xlsxPath, csvPath, outPath)
  .then(() => console.log("Done"))
  .catch(err => console.error(err));
