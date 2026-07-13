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

    // --- Mockup Dashboard Radial Progress Animation ---
    const radialFill = document.querySelector('.radial-fill');
    if (radialFill) {
        // Set transition property
        radialFill.style.transition = 'stroke-dashoffset 1.8s cubic-bezier(0.4, 0, 0.2, 1)';
        radialFill.style.strokeDashoffset = '251.2'; // start empty
        
        // Trigger fill animation when header section is visible
        const animateRadial = () => {
            const rect = radialFill.getBoundingClientRect();
            if (rect.top < window.innerHeight && rect.bottom > 0) {
                // 74% progress = 251.2 - (251.2 * 0.74) = 65.3
                radialFill.style.strokeDashoffset = '65.3';
                window.removeEventListener('scroll', animateRadial);
            }
        };
        window.addEventListener('scroll', animateRadial);
        setTimeout(animateRadial, 300); // trigger on load
    }
});
