#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
LAB_ROOT = SCRIPT_DIR.parent
OUTPUT_DIR = LAB_ROOT / 'output'
OFFLINE_CSV = OUTPUT_DIR / 'offline' / 'metrics_summary.csv'
ONLINE_CSV = OUTPUT_DIR / 'online' / 'summary.csv'
REPORT_PATH = OUTPUT_DIR / 'report.md'


def read_csv(path: Path):
    if not path.exists():
        return []
    with path.open() as f:
        reader = csv.DictReader(f)
        return list(reader)


def format_table(headers, rows):
    header_line = '| ' + ' | '.join(headers) + ' |'
    separator = '| ' + ' | '.join(['---'] * len(headers)) + ' |'
    body = ['| ' + ' | '.join(row) + ' |' for row in rows]
    return '\n'.join([header_line, separator] + body)


def select_offline_rows(rows):
    filtered = [r for r in rows if r['run'].startswith('lab_offline')]
    best_per_model = {}
    for row in filtered:
        model = row['model']
        rmse = float(row.get('rmse', 'inf') or 9999)
        if model not in best_per_model or rmse < best_per_model[model][0]:
            best_per_model[model] = (rmse, row)
    return [best_per_model[m][1] for m in sorted(best_per_model.keys())]


def human_scenario(name: str) -> str:
    mapping = {
        'baseline_hpa': 'Standart HPA',
        'phpa_linear': 'PHPA Linear',
        'phpa_holtwinters': 'PHPA Holt-Winters',
        'phpa_gbdt': 'PHPA GBDT',
        'phpa_catboost': 'PHPA CatBoost',
        'phpa_var': 'PHPA VAR',
        'phpa_xgboost': 'PHPA XGBoost',
    }
    return mapping.get(name, name)


def main():
    parser = argparse.ArgumentParser(description='Laboratuvar raporu oluşturur')
    parser.add_argument('--report', type=Path, default=REPORT_PATH)
    args = parser.parse_args()

    offline_rows = select_offline_rows(read_csv(OFFLINE_CSV))
    online_rows = read_csv(ONLINE_CSV)

    lines = ['# PHPA Laboratuvar Raporu']

    if offline_rows:
        lines.append('\n## Offline Model Karşılaştırması')
        offline_table = format_table(
            ['Model', 'Çalışma', 'RMSE', 'MAE', 'MAPE (%)'],
            [
                [row['model'], row['run'], f"{float(row['rmse']):.3f}", f"{float(row['mae']):.3f}", f"{float(row['mape']):.2f}"]
                for row in offline_rows
            ]
        )
        lines.append('\n' + offline_table)
    else:
        lines.append('\n## Offline Model Karşılaştırması\nVeri bulunamadı. `make -C labs offline` çalıştırın.')

    if online_rows:
        lines.append('\n## Online Deney Özeti')
        formatted = []
        for row in online_rows:
            formatted.append([
                human_scenario(row['scenario']),
                f"{float(row['duration']):.0f}",
                f"{float(row['desired_peak']):.1f}",
                f"{float(row['time_to_first_scale']) if row['time_to_first_scale'] else 0:.1f}",
                f"{float(row['cpu_peak_millicores']):.1f}",
                f"{float(row['cpu_mean_millicores']):.1f}",
                f"{float(row['mean_desired']):.2f}"
            ])
        online_table = format_table(
            ['Senaryo', 'Süre (sn)', 'Zirve Replika', 'İlk Ölçekleme (sn)',
             'CPU Zirve (m)', 'CPU Ortalama (m)', 'Ortalama Replika'],
            formatted
        )
        lines.append('\n' + online_table)
    else:
        lines.append('\n## Online Deney Özeti\nVeri bulunamadı. `make -C labs online` çalıştırın.')

    lines.append('\n## Notlar')
    lines.append('- Offline veriler `labs/data/generated/` içinde saklanır.')
    lines.append('- Online ham ölçümler `labs/output/online/raw/` dizininde CSV formatında bulunur.')
    lines.append('- Scriptler çalışma loglarını `labs/output/logs/` dizininde tutar.')

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text('\n'.join(lines))
    print(f"Rapor yazıldı: {args.report}")


if __name__ == '__main__':
    main()
