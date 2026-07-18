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

    // 5. Interactive Client Portal Showcase (Morphing Card)
    const btnFreelancer = document.getElementById('view-freelancer');
    const btnClient = document.getElementById('view-client');
    const freelancerFields = document.getElementById('freelancer-fields');
    const clientFields = document.getElementById('client-fields');
    const morphingTitle = document.getElementById('morphing-title');
    const morphingBadge = document.getElementById('morphing-badge');
    const morphingStatus = document.getElementById('morphing-status');

    if (btnFreelancer && btnClient) {
        btnFreelancer.addEventListener('click', () => {
            btnFreelancer.classList.add('active');
            btnClient.classList.remove('active');
            
            // Morph fields
            if (freelancerFields && clientFields) {
                clientFields.style.display = 'none';
                freelancerFields.style.display = 'block';
                setTimeout(() => {
                    freelancerFields.classList.add('active');
                    clientFields.classList.remove('active');
                }, 20);
            }
            
            // Update labels
            if (morphingTitle) morphingTitle.textContent = 'Editor Workspace';
            if (morphingBadge) {
                morphingBadge.textContent = 'Active Project';
                morphingBadge.style.backgroundColor = 'rgba(255,255,255,0.06)';
                morphingBadge.style.color = 'var(--text-muted)';
            }
            if (morphingStatus) {
                morphingStatus.textContent = 'In Review';
                morphingStatus.style.backgroundColor = 'rgba(245, 158, 11, 0.1)';
                morphingStatus.style.color = '#f59e0b';
            }
        });

        btnClient.addEventListener('click', () => {
            btnClient.classList.add('active');
            btnFreelancer.classList.remove('active');
            
            // Morph fields
            if (freelancerFields && clientFields) {
                freelancerFields.style.display = 'none';
                clientFields.style.display = 'block';
                setTimeout(() => {
                    clientFields.classList.add('active');
                    freelancerFields.classList.remove('active');
                }, 20);
            }
            
            // Update labels
            if (morphingTitle) morphingTitle.textContent = 'Client Portal';
            if (morphingBadge) {
                morphingBadge.textContent = 'Client: Alex K.';
                morphingBadge.style.backgroundColor = 'rgba(16, 185, 129, 0.1)';
                morphingBadge.style.color = 'var(--secondary)';
            }
            if (morphingStatus) {
                morphingStatus.textContent = 'Awaiting Pay';
                morphingStatus.style.backgroundColor = 'rgba(239, 68, 68, 0.1)';
                morphingStatus.style.color = '#ef4444';
            }
        });
    }

    // 6. Interactive Video Review Player (Scrubbing Dots)
    const commentDots = document.querySelectorAll('.comment-dot');
    const playerFill = document.getElementById('player-fill');
    const playerTimecode = document.getElementById('player-timecode');
    const reviewAuthor = document.getElementById('review-author');
    const reviewText = document.getElementById('review-text');
    const reviewStatus = document.getElementById('review-status');

    if (commentDots.length > 0) {
        commentDots.forEach(dot => {
            dot.addEventListener('click', () => {
                // Set active dot
                commentDots.forEach(d => d.classList.remove('active'));
                dot.classList.add('active');
                
                // Get data attributes
                const time = dot.getAttribute('data-time');
                const text = dot.getAttribute('data-comment');
                const author = dot.getAttribute('data-author');
                const left = dot.style.left;
                
                // Update player progress bar width
                if (playerFill) {
                    playerFill.style.width = left;
                }
                
                // Update timecode
                if (playerTimecode) {
                    playerTimecode.textContent = `${time} / 02:30`;
                }
                
                // Update review comment card with a smooth animation
                const bubbleCard = document.getElementById('review-bubble-card');
                if (bubbleCard) {
                    bubbleCard.style.opacity = '0';
                    bubbleCard.style.transform = 'translateY(10px)';
                    bubbleCard.style.transition = 'opacity 0.2s ease, transform 0.2s ease';
                    
                    setTimeout(() => {
                        if (reviewAuthor) {
                            reviewAuthor.innerHTML = `${author} <span style="font-family: monospace; font-size: 10px; color: var(--text-muted);">@${time}</span>`;
                        }
                        if (reviewText) {
                            reviewText.textContent = text;
                        }
                        
                        // Dynamic status badge updates
                        if (reviewStatus) {
                            if (time === '00:45') {
                                reviewStatus.textContent = 'Approved';
                                reviewStatus.style.backgroundColor = 'rgba(16, 185, 129, 0.1)';
                                reviewStatus.style.color = 'var(--secondary)';
                            } else {
                                reviewStatus.textContent = 'Feedback';
                                reviewStatus.style.backgroundColor = 'rgba(239, 68, 68, 0.1)';
                                reviewStatus.style.color = '#ef4444';
                            }
                        }
                        
                        bubbleCard.style.opacity = '1';
                        bubbleCard.style.transform = 'translateY(0)';
                    }, 200);
                }
            });
        });
    }

    // 7. Watch Demo Modal Controller
    const btnWatchDemo = document.getElementById('btn-watch-demo');
    const watchModal = document.getElementById('watch-demo-modal');
    const modalCloseBtn = document.getElementById('modal-close-btn');
    const modalOverlay = watchModal ? watchModal.querySelector('.modal-overlay') : null;
    
    // Walkthrough simulation elements
    const btnModalPlay = document.getElementById('btn-modal-play');
    const btnModalPause = document.getElementById('btn-modal-pause');
    const modalPlaceholder = document.getElementById('modal-placeholder');
    const modalPlaying = document.getElementById('modal-playing');
    const modalProgressFill = document.getElementById('modal-progress-fill');
    const modalTimer = document.getElementById('modal-timer');
    const modalStatusText = document.getElementById('modal-status-text');

    let demoTimer = null;
    let demoProgress = 0;
    const demoDuration = 90; // 1:30 in seconds
    let isDemoPlaying = false;

    function formatTime(seconds) {
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
    }

    function updateDemoStatus(seconds) {
        if (!modalStatusText) return;
        if (seconds < 15) {
            modalStatusText.textContent = "Loading frame-accurate review player...";
        } else if (seconds < 35) {
            modalStatusText.textContent = "Initializing secure guest share review links...";
        } else if (seconds < 60) {
            modalStatusText.textContent = "Simulating real-time editor-client comment flow...";
        } else if (seconds < 80) {
            modalStatusText.textContent = "Compiling auto-filled PDF invoice with UPI QR checkout...";
        } else {
            modalStatusText.textContent = "Walkthrough complete! Experience the power of EditFlow.";
        }
    }

    function startDemoSimulation() {
        if (demoTimer) clearInterval(demoTimer);
        isDemoPlaying = true;
        if (btnModalPause) btnModalPause.textContent = "⏸ Pause";

        demoTimer = setInterval(() => {
            if (demoProgress < demoDuration) {
                demoProgress++;
                if (modalProgressFill) {
                    modalProgressFill.style.width = `${(demoProgress / demoDuration) * 100}%`;
                }
                if (modalTimer) {
                    modalTimer.textContent = `${formatTime(demoProgress)} / 1:30`;
                }
                updateDemoStatus(demoProgress);
            } else {
                // Done
                clearInterval(demoTimer);
                resetDemoSimulation();
            }
        }, 1000);
    }

    function pauseDemoSimulation() {
        isDemoPlaying = false;
        if (btnModalPause) btnModalPause.textContent = "▶ Resume";
        if (demoTimer) clearInterval(demoTimer);
    }

    function resetDemoSimulation() {
        if (demoTimer) clearInterval(demoTimer);
        demoProgress = 0;
        isDemoPlaying = false;
        if (modalProgressFill) modalProgressFill.style.width = '0%';
        if (modalTimer) modalTimer.textContent = '0:00 / 1:30';
        if (modalStatusText) modalStatusText.textContent = 'Simulating Workspace Demo...';
        if (modalPlaceholder) modalPlaceholder.style.display = 'flex';
        if (modalPlaying) modalPlaying.style.display = 'none';
        if (btnModalPause) btnModalPause.textContent = "⏸ Pause";
    }

    if (btnWatchDemo && watchModal) {
        btnWatchDemo.addEventListener('click', () => {
            watchModal.classList.add('active');
            document.body.style.overflow = 'hidden'; // prevent back scroll
        });

        const closeModal = () => {
            watchModal.classList.remove('active');
            document.body.style.overflow = '';
            resetDemoSimulation();
        };

        if (modalCloseBtn) modalCloseBtn.addEventListener('click', closeModal);
        if (modalOverlay) modalOverlay.addEventListener('click', closeModal);
    }

    if (btnModalPlay && modalPlaceholder && modalPlaying) {
        btnModalPlay.addEventListener('click', () => {
            modalPlaceholder.style.display = 'none';
            modalPlaying.style.display = 'block';
            startDemoSimulation();
        });
    }

    if (btnModalPause) {
        btnModalPause.addEventListener('click', () => {
            if (isDemoPlaying) {
                pauseDemoSimulation();
            } else {
                startDemoSimulation();
            }
        });
    }
});
