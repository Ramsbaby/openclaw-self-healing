#!/usr/bin/env python3
"""Generate GitHub traffic chart"""
import os, sys, json, requests
from datetime import datetime
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

def fetch_traffic(repo, token):
    h = {"Authorization": f"token {token}", "Accept": "application/vnd.github.v3+json"}
    base = f"https://api.github.com/repos/{repo}/traffic"
    return requests.get(f"{base}/views", headers=h).json(), \
           requests.get(f"{base}/clones", headers=h).json()

def generate_chart(views_data, clones_data, output):
    dates, views, clones = [], [], []
    
    for item in views_data.get('views', []):
        date = datetime.strptime(item['timestamp'][:10], '%Y-%m-%d')
        dates.append(date)
        views.append(item['count'])
    
    clone_dict = {datetime.strptime(item['timestamp'][:10], '%Y-%m-%d'): item['count']
                  for item in clones_data.get('clones', [])}
    clones = [clone_dict.get(date, 0) for date in dates]
    
    fig, ax = plt.subplots(figsize=(12, 6))
    ax.plot(dates, views, marker='o', label='Views', color='#2ea44f', linewidth=2)
    ax.plot(dates, clones, marker='s', label='Clones', color='#0969da', linewidth=2)
    
    ax.set_xlabel('Date', fontsize=12)
    ax.set_ylabel('Count', fontsize=12)
    ax.set_title('openclaw-self-healing Traffic (Last 14 Days)', fontsize=14, fontweight='bold')
    ax.legend(loc='upper left', fontsize=11)
    ax.grid(True, alpha=0.3)
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'))
    ax.xaxis.set_major_locator(mdates.DayLocator(interval=2))
    plt.xticks(rotation=45)
    
    summary = f"Total: {views_data.get('count', 0)} views ({views_data.get('uniques', 0)} unique) • " \
              f"{clones_data.get('count', 0)} clones ({clones_data.get('uniques', 0)} unique)"
    plt.figtext(0.5, 0.02, summary, ha='center', fontsize=10, style='italic')
    
    plt.tight_layout()
    plt.savefig(output, dpi=150, bbox_inches='tight')
    print(f"✅ Chart saved: {output}")
    
    return {"total_views": views_data.get('count', 0), "unique_views": views_data.get('uniques', 0),
            "total_clones": clones_data.get('count', 0), "unique_clones": clones_data.get('uniques', 0)}

if __name__ == "__main__":
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        print("❌ GITHUB_TOKEN not set")
        sys.exit(1)
    
    repo = "Ramsbaby/openclaw-self-healing"
    print(f"📊 Fetching traffic for {repo}...")
    views, clones = fetch_traffic(repo, token)
    
    print("📈 Generating chart...")
    stats = generate_chart(views, clones, "assets/traffic-chart.png")
    
    with open('traffic-stats.json', 'w') as f:
        json.dump(stats, f, indent=2)
    
    print(f"✅ Done! Views: {stats['total_views']}, Clones: {stats['total_clones']}")
