// Graph creation module
// Creates and displays financial metric graphs directly in the DOM

/**
 * Creates a graph for a financial metric and inserts it into the specified container
 * @param container - The DOM element to insert the graph into
 * @param ticker - The ticker symbol of the firm
 * @param rssd_id - The RSSD ID of the firm
 * @param metric - The financial metric name
 */
export function create(container: HTMLElement, ticker: string, rssd_id: string, metric: string): void {
    // Clear any existing content
    container.innerHTML = '';
    
    // Create graph container with styling
    const graphDiv = document.createElement('div');
    graphDiv.className = 'metric-graph';
    graphDiv.style.cssText = `
        background: #2a2a2a;
        border: 2px solid #4a9eff;
        border-radius: 8px;
        padding: 20px;
        margin: 10px 0;
        min-height: 300px;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
    `;
    
    // Create title
    const title = document.createElement('h3');
    title.textContent = `${metric} - ${ticker}`;
    title.style.cssText = `
        color: #4a9eff;
        margin: 0 0 20px 0;
        font-size: 18px;
        text-align: center;
    `;
    
    // Create placeholder chart area
    const chartArea = document.createElement('div');
    chartArea.style.cssText = `
        width: 100%;
        height: 200px;
        background: linear-gradient(45deg, #1a1a1a 25%, transparent 25%), 
                    linear-gradient(-45deg, #1a1a1a 25%, transparent 25%), 
                    linear-gradient(45deg, transparent 75%, #1a1a1a 75%), 
                    linear-gradient(-45deg, transparent 75%, #1a1a1a 75%);
        background-size: 20px 20px;
        background-position: 0 0, 0 10px, 10px -10px, -10px 0px;
        border: 1px solid #444;
        border-radius: 4px;
        display: flex;
        align-items: center;
        justify-content: center;
        position: relative;
    `;
    
    // Create sample data visualization
    const dataPoints = generateSampleData();
    const svg = createSVGChart(dataPoints, metric);
    chartArea.appendChild(svg);
    
    // Create info text
    const info = document.createElement('p');
    info.textContent = `Displaying ${metric} trend data for ${ticker} (RSSD ID: ${rssd_id})`;
    info.style.cssText = `
        color: #ccc;
        margin: 15px 0 0 0;
        font-size: 14px;
        text-align: center;
    `;
    
    // Assemble the graph
    graphDiv.appendChild(title);
    graphDiv.appendChild(chartArea);
    graphDiv.appendChild(info);
    
    // Insert into container and make visible
    container.appendChild(graphDiv);
    container.style.display = 'block';
}

/**
 * Generates sample data points for demonstration
 */
function generateSampleData(): number[] {
    const points = [];
    const baseValue = 100;
    let currentValue = baseValue;
    
    for (let i = 0; i < 12; i++) {
        // Add some realistic variation
        const change = (Math.random() - 0.5) * 20;
        currentValue += change;
        points.push(Math.max(0, currentValue));
    }
    
    return points;
}

/**
 * Creates an SVG line chart
 */
function createSVGChart(dataPoints: number[], metric: string): SVGElement {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '100%');
    svg.setAttribute('height', '100%');
    svg.setAttribute('viewBox', '0 0 400 180');
    
    const maxValue = Math.max(...dataPoints);
    const minValue = Math.min(...dataPoints);
    const range = maxValue - minValue || 1;
    
    // Create path for line chart
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    let pathData = '';
    
    dataPoints.forEach((value, index) => {
        const x = (index / (dataPoints.length - 1)) * 360 + 20;
        const y = 160 - ((value - minValue) / range) * 140;
        
        if (index === 0) {
            pathData += `M ${x} ${y}`;
        } else {
            pathData += ` L ${x} ${y}`;
        }
    });
    
    path.setAttribute('d', pathData);
    path.setAttribute('stroke', '#4a9eff');
    path.setAttribute('stroke-width', '2');
    path.setAttribute('fill', 'none');
    
    // Add data points
    dataPoints.forEach((value, index) => {
        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        const x = (index / (dataPoints.length - 1)) * 360 + 20;
        const y = 160 - ((value - minValue) / range) * 140;
        
        circle.setAttribute('cx', x.toString());
        circle.setAttribute('cy', y.toString());
        circle.setAttribute('r', '3');
        circle.setAttribute('fill', '#4a9eff');
        
        svg.appendChild(circle);
    });
    
    svg.appendChild(path);
    
    return svg;
}
