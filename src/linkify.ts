// Financial metrics linkification module
// Converts financial metric references in text to clickable links that display graphs

import Database from 'duckdb';
import path from 'path';

// Cache for metrics to avoid repeated DB queries
const metricsCache = new Map<string, string[]>();
const CACHE_EXPIRY = 5 * 60 * 1000; // 5 minutes
const cacheTimestamps = new Map<string, number>();

/**
 * Gets populated financial metrics for a specific firm from the database
 * @param rssd_id - The RSSD ID of the firm
 * @returns Promise<string[]> - Array of metric names populated for this firm
 */
async function getPopulatedMetrics(rssd_id: string): Promise<string[]> {
    const cacheKey = rssd_id;
    const now = Date.now();
    
    // Check cache first
    if (metricsCache.has(cacheKey) && cacheTimestamps.has(cacheKey)) {
        const cacheTime = cacheTimestamps.get(cacheKey)!;
        if (now - cacheTime < CACHE_EXPIRY) {
            return metricsCache.get(cacheKey)!;
        }
    }
    
    return new Promise((resolve, reject) => {
        const dbPath = path.join(__dirname, '../data/mydb.duckdb');
        const db = new Database.Database(dbPath);
        
        const query = `
            SELECT DISTINCT property_name 
            FROM financial_metrics 
            WHERE rssd_id = ? 
            ORDER BY property_name
        `;
        
        db.all(query, [rssd_id], (err: Error | null, rows: any[]) => {
            db.close();
            
            if (err) {
                console.error('Error querying metrics from database:', err);
                reject(err);
                return;
            }
            
            const metrics = rows.map(row => row.property_name);
            
            // Update cache
            metricsCache.set(cacheKey, metrics);
            cacheTimestamps.set(cacheKey, now);
            
            resolve(metrics);
        });
    });
}

/**
 * Adds clickable links to financial metric references in text
 * @param text - The text content to process
 * @param ticker - The ticker symbol of the current firm
 * @param rssd_id - The RSSD ID of the current firm
 * @returns Promise<string> - The text with financial metrics converted to clickable links
 */
export async function add_graph_links(text: string, ticker: string, rssd_id: string): Promise<string> {
    console.log(`[LINKIFY] Starting linkification for ${ticker} (${rssd_id})`);
    console.log(`[LINKIFY] Input text length: ${text.length}`);
    
    if (!text || !ticker || !rssd_id) {
        console.log(`[LINKIFY] Missing parameters: text=${!!text}, ticker=${ticker}, rssd_id=${rssd_id}`);
        return text;
    }
    
    try {
        // Get populated metrics for this firm from the database
        console.log(`[LINKIFY] Querying database for metrics...`);
        const populatedMetrics = await getPopulatedMetrics(rssd_id);
        console.log(`[LINKIFY] Found ${populatedMetrics.length} metrics`);
        console.log(`[LINKIFY] First 5 metrics:`, populatedMetrics.slice(0, 5));
        
        if (!populatedMetrics || populatedMetrics.length === 0) {
            console.log(`[LINKIFY] No metrics found, returning original text`);
            return text;
        }
        
        let processedText = text;
        let replacementCount = 0;
        
        // Sort metrics by length (longest first) to handle superset names correctly
        // This ensures longer metric names that contain shorter ones are matched first
        const sortedMetrics = populatedMetrics.sort((a: string, b: string) => b.length - a.length);
        
        for (const metric of sortedMetrics) {
            // Create a case-insensitive regex that matches the metric
            // Use word boundaries to avoid partial matches
            // Also ensure we don't match text that's already inside HTML tags
            const regex = new RegExp(`\\b${metric.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b(?![^<]*>)`, 'gi');
            
            const beforeLength = processedText.length;
            processedText = processedText.replace(regex, (match, offset, string) => {
                // Check if this match is inside an existing link tag
                const beforeMatch = string.substring(0, offset);
                const openTags = (beforeMatch.match(/<a[^>]*>/g) || []).length;
                const closeTags = (beforeMatch.match(/<\/a>/g) || []).length;
                
                // If we're inside an unclosed <a> tag, skip this match
                if (openTags > closeTags) {
                    return match; // Don't replace, return original
                }
                
                replacementCount++;
                console.log(`[LINKIFY] Replacing "${match}" with link`);
                
                // Encode the metric name for URL safety
                const encodedMetric = encodeURIComponent(match);
                
                // Generate unique ID for the graph container
                const graphId = `graph-${ticker}-${rssd_id}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
                
                // Escape single quotes in the match for safe HTML attribute usage
                const escapedMatch = match.replace(/'/g, '&#39;');
                
                // Create a clickable link with hidden div for graph
                return `<a href="#" class="metric-link" data-ticker="${ticker}" data-rssd-id="${rssd_id}" data-metric="${encodedMetric}" data-graph-id="${graphId}" onclick="createGraph(document.getElementById('${graphId}'), '${ticker}', '${rssd_id}', '${escapedMatch}')">${match}</a><div id="${graphId}" class="metric-graph-container" style="display: none;"></div>`;
            });
            
            if (processedText.length !== beforeLength) {
                console.log(`[LINKIFY] Metric "${metric}" found and replaced`);
            }
        }
        
        console.log(`[LINKIFY] Linkification complete. Made ${replacementCount} replacements`);
        console.log(`[LINKIFY] Output text length: ${processedText.length}`);
        
        return processedText;
    } catch (error) {
        console.error('[LINKIFY] Error getting populated metrics for linkification:', error);
        return text; // Return original text if DB query fails
    }
}

/**
 * Checks if a firm is currently set as the focal point
 * @param currentFirm - The current firm object or null
 * @returns boolean indicating if a firm is set
 */
export function hasFocalFirm(currentFirm: {ticker: string, rssd_id: string} | null): boolean {
    return currentFirm !== null && Boolean(currentFirm.ticker) && Boolean(currentFirm.rssd_id);
}
