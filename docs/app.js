document.addEventListener('DOMContentLoaded', () => {
    // Mobile menu toggle
    const menuToggle = document.querySelector('.mobile-menu-toggle');
    const navLinks = document.querySelector('.nav-links');

    if (menuToggle && navLinks) {
        menuToggle.addEventListener('click', () => {
            navLinks.classList.toggle('active');
            
            // Animate toggle button spans
            const spans = menuToggle.querySelectorAll('span');
            if (navLinks.classList.contains('active')) {
                spans[0].style.transform = 'rotate(45deg) translate(5px, 5px)';
                spans[1].style.opacity = '0';
                spans[2].style.transform = 'rotate(-45deg) translate(7px, -8px)';
            } else {
                spans[0].style.transform = 'none';
                spans[1].style.opacity = '1';
                spans[2].style.transform = 'none';
            }
        });
    }

    // Scroll reveal micro-animations
    const revealElements = document.querySelectorAll('.feature-card, .portal-feature-item, .comp-box');
    
    const revealOnScroll = () => {
        const triggerBottom = window.innerHeight * 0.85;
        
        revealElements.forEach(el => {
            const elTop = el.getBoundingClientRect().top;
            
            if (elTop < triggerBottom) {
                el.style.opacity = '1';
                el.style.transform = 'translateY(0)';
            }
        });
    };

    // Initialize animation properties
    revealElements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(20px)';
        el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    });

    window.addEventListener('scroll', revealOnScroll);
    revealOnScroll(); // Trigger once on load

    // --- Interactive Video Feedback Simulator Logic ---
    const simComments = document.querySelectorAll('.sim-comment-item');
    const simVideoCanvas = document.getElementById('simVideoCanvas');
    const sceneContent = document.getElementById('sceneContent');
    const timelineFill = document.getElementById('timelineFill');
    const timelineHandle = document.getElementById('timelineHandle');
    const timeCurrent = document.getElementById('timeCurrent');
    
    // Config for each simulator state
    const simStates = {
        '15': {
            filter: 'glow',
            text: '✨ Brand Logo (Glowing) ✨',
            timeStr: '0:15',
            fillPct: '15%'
        },
        '45': {
            filter: 'grayscale',
            text: '🎬 B&W Cinematic Scene',
            timeStr: '0:45',
            fillPct: '45%'
        },
        '80': {
            filter: 'neonText',
            text: '🎬 EditFlow Web Portal',
            timeStr: '1:20',
            fillPct: '80%'
        }
    };

    let activeStateId = '15';
    let autoCycleTimer = null;

    const setSimulatorState = (stateId) => {
        const state = simStates[stateId];
        if (!state) return;

        activeStateId = stateId;

        // Update comments active status
        simComments.forEach(item => {
            if (item.getAttribute('data-marker') === stateId) {
                item.classList.add('active');
                item.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            } else {
                item.classList.remove('active');
            }
        });

        // Update video canvas filter classes
        simVideoCanvas.className = 'sim-video-canvas'; // reset
        if (state.filter) {
            simVideoCanvas.classList.add(state.filter);
        }

        // Update screen text
        sceneContent.textContent = state.text;

        // Update timeline graphics
        timelineFill.style.width = state.fillPct;
        timelineHandle.style.left = state.fillPct;
        timeCurrent.textContent = state.timeStr;
    };

    const startAutoCycle = () => {
        stopAutoCycle();
        autoCycleTimer = setInterval(() => {
            const keys = Object.keys(simStates);
            const currentIndex = keys.indexOf(activeStateId);
            const nextIndex = (currentIndex + 1) % keys.length;
            setSimulatorState(keys[nextIndex]);
        }, 5000); // cycle every 5 seconds
    };

    const stopAutoCycle = () => {
        if (autoCycleTimer) {
            clearInterval(autoCycleTimer);
            autoCycleTimer = null;
        }
    };

    // Add click event listeners to comments
    simComments.forEach(item => {
        item.addEventListener('click', () => {
            stopAutoCycle();
            const marker = item.getAttribute('data-marker');
            setSimulatorState(marker);
            // Restart cycle after 10s of inactivity
            setTimeout(startAutoCycle, 10000);
        });

        item.addEventListener('mouseenter', () => {
            stopAutoCycle();
            const marker = item.getAttribute('data-marker');
            setSimulatorState(marker);
        });

        item.addEventListener('mouseleave', () => {
            startAutoCycle();
        });
    });

    // Initialize Simulator
    setSimulatorState('15');
    startAutoCycle();
});
