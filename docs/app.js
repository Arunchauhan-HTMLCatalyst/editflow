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

    // Dropdown click toggle
    const dropdown = document.querySelector('.dropdown');
    const dropdownToggle = document.querySelector('.dropdown-toggle');
    if (dropdown && dropdownToggle) {
        dropdownToggle.addEventListener('click', (e) => {
            e.stopPropagation();
            dropdown.classList.toggle('active');
        });
        
        window.addEventListener('click', (e) => {
            if (!dropdown.contains(e.target)) {
                dropdown.classList.remove('active');
            }
        });
    }

    // FAQ Accordion Toggle Action
    const faqItems = document.querySelectorAll('.faq-item');
    faqItems.forEach(item => {
        const questionBtn = item.querySelector('.faq-question');
        const answerEl = item.querySelector('.faq-answer');
        
        if (questionBtn && answerEl) {
            questionBtn.addEventListener('click', () => {
                const isActive = item.classList.contains('active');
                
                // Close all other items
                faqItems.forEach(otherItem => {
                    if (otherItem !== item) {
                        otherItem.classList.remove('active');
                        const otherAnswer = otherItem.querySelector('.faq-answer');
                        if (otherAnswer) otherAnswer.style.maxHeight = '0';
                    }
                });
                
                // Toggle current item
                item.classList.toggle('active');
                if (item.classList.contains('active')) {
                    answerEl.style.maxHeight = answerEl.scrollHeight + 'px';
                } else {
                    answerEl.style.maxHeight = '0';
                }
            });
        }
    });

    // ==========================================
    // PURE CSS SCROLL REVEAL & PRELOADER SYSTEM
    // ==========================================

    // 1. Setup Hero Reveal Classes & Delays
    const heroContentBadge = document.querySelector('.hero-content .badge');
    const heroContentTitle = document.querySelector('.hero-content h1');
    const heroContentDesc = document.querySelector('.hero-content p');
    const heroContentActions = document.querySelector('.hero-actions');
    const heroMetaSpans = document.querySelectorAll('.hero-meta span');
    const heroVisual = document.querySelector('.hero-visual');

    // Add classes and animation delays programmatically
    if (heroContentBadge) {
        heroContentBadge.classList.add('reveal-on-scroll');
        heroContentBadge.style.transitionDelay = '0.05s';
    }
    if (heroContentTitle) {
        heroContentTitle.classList.add('reveal-on-scroll');
        heroContentTitle.style.transitionDelay = '0.15s';
    }
    if (heroContentDesc) {
        heroContentDesc.classList.add('reveal-on-scroll');
        heroContentDesc.style.transitionDelay = '0.25s';
    }
    if (heroContentActions) {
        heroContentActions.classList.add('reveal-on-scroll');
        heroContentActions.style.transitionDelay = '0.35s';
    }
    heroMetaSpans.forEach((span, idx) => {
        span.classList.add('reveal-on-scroll');
        span.style.transitionDelay = `${0.45 + idx * 0.08}s`;
    });
    if (heroVisual) {
        heroVisual.classList.add('reveal-on-scroll', 'reveal-scale');
        heroVisual.style.transitionDelay = '0.35s';
    }

    // 2. Setup Scroll Reveal Elements & Delays
    const featureCards = document.querySelectorAll('.feature-card');
    featureCards.forEach((card, idx) => {
        card.classList.add('reveal-on-scroll');
        // Reset delay every 4 items (assuming grid has 4 items in a row on desktop)
        const delay = (idx % 4) * 0.08;
        card.style.transitionDelay = `${delay}s`;
    });

    const portalItemsLeft = document.querySelectorAll('#client .portal-feature-item');
    portalItemsLeft.forEach((item, idx) => {
        item.classList.add('reveal-on-scroll', 'reveal-left');
        item.style.transitionDelay = `${idx * 0.1}s`;
    });

    const portalItemsRight = document.querySelectorAll('#reviews-system .portal-feature-item');
    portalItemsRight.forEach((item, idx) => {
        item.classList.add('reveal-on-scroll', 'reveal-right');
        item.style.transitionDelay = `${idx * 0.1}s`;
    });

    const portalMockupLeft = document.querySelector('#client .portal-mockup-wrapper');
    if (portalMockupLeft) {
        portalMockupLeft.classList.add('reveal-on-scroll', 'reveal-scale');
        portalMockupLeft.style.transitionDelay = '0.2s';
    }

    const portalMockupRight = document.querySelector('#reviews-system .portal-mockup-wrapper');
    if (portalMockupRight) {
        portalMockupRight.classList.add('reveal-on-scroll', 'reveal-scale');
        portalMockupRight.style.transitionDelay = '0.2s';
    }

    const compBoxes = document.querySelectorAll('#why-us .comp-box');
    compBoxes.forEach((box, idx) => {
        box.classList.add('reveal-on-scroll');
        box.style.transitionDelay = `${idx * 0.15}s`;
    });

    const pricingCards = document.querySelectorAll('.pricing-card');
    pricingCards.forEach((card, idx) => {
        card.classList.add('reveal-on-scroll');
        card.style.transitionDelay = `${idx * 0.12}s`;
    });

    // 3. Preloader Simulated Progress Bar Count
    const progressFill = document.querySelector('.preloader-progress-fill');
    const percentText = document.getElementById('preloader-percent');
    let progress = 0;

    const startAppEntrance = () => {
        // Fade out preloader overlay
        const preloaderEl = document.getElementById('preloader');
        if (preloaderEl) {
            preloaderEl.style.opacity = '0';
            preloaderEl.style.visibility = 'hidden';
            setTimeout(() => {
                preloaderEl.style.display = 'none';
            }, 600);
        }

        // Trigger Hero entry animations immediately
        const heroElements = [
            heroContentBadge,
            heroContentTitle,
            heroContentDesc,
            heroContentActions,
            heroVisual
        ];
        heroElements.forEach(el => {
            if (el) el.classList.add('active');
        });
        heroMetaSpans.forEach(span => span.classList.add('active'));

        // Play radial goal tracker fill
        const radialFill = document.querySelector('.radial-fill');
        if (radialFill) {
            radialFill.style.transition = 'stroke-dashoffset 2s cubic-bezier(0.4, 0, 0.2, 1)';
            radialFill.style.strokeDashoffset = '251.2';
            setTimeout(() => {
                radialFill.style.strokeDashoffset = '65.3';
            }, 400);
        }
    };

    const updateProgress = () => {
        progress += Math.floor(Math.random() * 14) + 6;
        if (progress > 100) progress = 100;
        
        if (progressFill) progressFill.style.width = `${progress}%`;
        if (percentText) percentText.textContent = `${progress}%`;
        
        if (progress < 100) {
            setTimeout(updateProgress, Math.floor(Math.random() * 30) + 10);
        } else {
            setTimeout(startAppEntrance, 100);
        }
    };

    // Trigger preloader counting
    updateProgress();

    // 4. Intersection Observer for Scroll Reveals
    const observerOptions = {
        root: null,
        rootMargin: '0px 0px 150px 0px', // Pre-trigger elements 150px before entering screen
        threshold: 0.01
    };

    const revealObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('active');
                observer.unobserve(entry.target); // trigger animation only once
            }
        });
    }, observerOptions);

    // Observe all scroll reveal elements
    document.querySelectorAll('.reveal-on-scroll').forEach(el => {
        // Skip hero items as they are triggered immediately after preloader fades out
        if (el.closest('.hero')) return;
        revealObserver.observe(el);
    });
});
