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
    // GSAP ANIMATIONS (Safe Guarded)
    // ==========================================
    try {
        if (typeof gsap !== 'undefined' && typeof ScrollTrigger !== 'undefined') {
            gsap.registerPlugin(ScrollTrigger);

            // Hero Entrance Animations (Paused initially)
            const heroTl = gsap.timeline({ paused: true, defaults: { ease: 'power3.out', duration: 1 } });
            
            heroTl.from('.navbar', {
                y: -100,
                opacity: 0,
                duration: 0.8
            })
            .from('.hero-content .badge', {
                y: 20,
                opacity: 0,
            }, '-=0.4')
            .from('.hero-content h1', {
                y: 30,
                opacity: 0,
            }, '-=0.6')
            .from('.hero-content p', {
                y: 20,
                opacity: 0,
            }, '-=0.6')
            .from('.hero-actions a', {
                y: 20,
                opacity: 0,
                stagger: 0.15
            }, '-=0.6')
            .from('.hero-meta span', {
                x: -20,
                opacity: 0,
                stagger: 0.1
            }, '-=0.6')
            .from('.hero-visual', {
                scale: 0.95,
                opacity: 0,
                duration: 1.2
            }, '-=1.0');

            // Preloader Simulated Progress Bar Count
            const progressFill = document.querySelector('.preloader-progress-fill');
            const percentText = document.getElementById('preloader-percent');
            let progress = 0;

            const updateProgress = () => {
                // Advance progress randomly
                progress += Math.floor(Math.random() * 12) + 6;
                if (progress > 100) progress = 100;
                
                if (progressFill) progressFill.style.width = `${progress}%`;
                if (percentText) percentText.textContent = `${progress}%`;
                
                if (progress < 100) {
                    setTimeout(updateProgress, Math.floor(Math.random() * 60) + 20);
                } else {
                    // Preloader Complete: slide up or fade out overlay
                    setTimeout(() => {
                        gsap.to('#preloader', {
                            opacity: 0,
                            duration: 0.6,
                            ease: 'power3.inOut',
                            onComplete: () => {
                                const preloaderEl = document.getElementById('preloader');
                                if (preloaderEl) {
                                    preloaderEl.style.display = 'none';
                                    preloaderEl.style.visibility = 'hidden';
                                }
                                // Start the main Hero page animation!
                                heroTl.play();
                                // Refresh ScrollTrigger elements now that heights are calculated
                                ScrollTrigger.refresh();
                            }
                        });
                    }, 150);
                }
            };

            // Start preloader loading simulation
            updateProgress();

            // Stats progress tracker radial animation
            const radialFill = document.querySelector('.radial-fill');
            if (radialFill) {
                radialFill.style.strokeDashoffset = '251.2';
                
                gsap.to(radialFill, {
                    strokeDashoffset: '65.3',
                    duration: 2,
                    ease: 'power2.out',
                    scrollTrigger: {
                        trigger: '.mock-radial-container',
                        start: 'top 85%',
                        once: true
                    }
                });
            }

            // ScrollTrigger Animation for Freelancer Features Cards
            gsap.from('.feature-card', {
                scrollTrigger: {
                    trigger: '#freelancer',
                    start: 'top 85%',
                    once: true
                },
                y: 40,
                opacity: 0,
                stagger: 0.05,
                duration: 0.8,
                ease: 'power2.out'
            });

            // ScrollTrigger Animation for Client Portal Section
            gsap.from('#client .portal-feature-item', {
                scrollTrigger: {
                    trigger: '#client',
                    start: 'top 85%',
                    once: true
                },
                x: -40,
                opacity: 0,
                stagger: 0.08,
                duration: 0.8,
                ease: 'power2.out'
            });

            gsap.from('#client .portal-mockup-wrapper', {
                scrollTrigger: {
                    trigger: '#client',
                    start: 'top 80%',
                    once: true
                },
                scale: 0.9,
                opacity: 0,
                duration: 1,
                ease: 'power3.out'
            });

            // ScrollTrigger Animation for Video Review System Section
            gsap.from('#reviews-system .portal-feature-item', {
                scrollTrigger: {
                    trigger: '#reviews-system',
                    start: 'top 85%',
                    once: true
                },
                x: 40,
                opacity: 0,
                stagger: 0.08,
                duration: 0.8,
                ease: 'power2.out'
            });

            gsap.from('#reviews-system .portal-mockup-wrapper', {
                scrollTrigger: {
                    trigger: '#reviews-system',
                    start: 'top 80%',
                    once: true
                },
                scale: 0.9,
                opacity: 0,
                duration: 1,
                ease: 'power3.out'
            });

            // ScrollTrigger Animation for Why Us Section (Comparison boxes)
            gsap.from('#why-us .comp-box', {
                scrollTrigger: {
                    trigger: '#why-us',
                    start: 'top 85%',
                    once: true
                },
                y: 40,
                opacity: 0,
                stagger: 0.15,
                duration: 0.8,
                ease: 'power2.out'
            });

            // ScrollTrigger Animation for Pricing Section
            gsap.from('.pricing-card', {
                scrollTrigger: {
                    trigger: '#pricing',
                    start: 'top 85%',
                    once: true
                },
                y: 40,
                opacity: 0,
                stagger: 0.1,
                duration: 0.8,
                ease: 'power2.out'
            });
            
            // Refresh ScrollTrigger to recalculate layout dimensions
            ScrollTrigger.refresh();
        }
    } catch (e) {
        console.warn('GSAP initialization failed, using CSS animations fallback:', e);
        // Reset any properties set to hidden by default in CSS if applicable
    }
});
