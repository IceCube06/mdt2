$(function () {
    const alertSound = new Audio('/html/sounds/popup.mp3');
    alertSound.volume = 0.5;

    const App = Vue.createApp({
        data() {
            return {
                show: false,
                officerName: '',
                page: 'home',
                loading: false,

                searchQuery: '',
                searchResults: [],

                lastSearches: [],

                selectedResult: null,
                profile_page: 'warrant',

                profile: {
                    assets: [],
                    records: [],
                    newrecord: {
                        maxFine: 0,
                        maxPrison: 0,
                        desc: '',
                        search: '',

                        prison: 0,
                        fine: 0,
                        fines: [],
                    }
                },

                fines: [],
                warrants: [],
                selectedWarrant: [],

                callouts: [],
            }
        },

        methods: {

            openResult(resultId) {
                this.selectedResult = this.searchResults[resultId];
            },

            makeSearch() {
                let searchQuery = this.searchQuery.toLowerCase();
                if (searchQuery.length >= 3) {
                    this.loading = true; this.selectedResult = null;

                    $.post(`https://${GetParentResourceName()}/search`, JSON.stringify({ query: searchQuery }), (data) => {
                        if (typeof data != 'object') {
                            return showAlert('Server error.', 'error');
                        }

                        this.searchResults = data;

                        this.page = 'search';

                        this.lastSearches.push({ name: this.searchQuery });
                        if (this.lastSearches.length > 10) {
                            this.lastSearches.shift();
                        }

                        this.loading = false;
                    })
                } else {
                    showAlert('Otsingus peab olema vähemalt kolm tähemärki.', 'error');

                    if (this.page != 'home') {
                        this.page = 'home';
                    }
                }
            },

            filteredFines() {
                const Fines = this.fines;
                const FilteredFines = [];

                let searchQuery = this.profile.newrecord.search.toLowerCase() || '';
                for (let i = 0; i < Fines.length; i++) {
                    let fine = Fines[i];

                    if (fine.label.toLowerCase().includes(searchQuery)) {
                        let text = `${fine.label} - (${fine.value}€)`;
                        FilteredFines.push({
                            label: text,
                            prison: fine.prison,
                            id: i,
                        });
                    }
                }

                return FilteredFines;
            },

            addFine(fineIdx) {
                const Fines = this.fines;
                let fine = Fines[fineIdx];

                if (this.profile.newrecord.fines.includes(fine)) {
                    fine.times += 1;
                } else {
                    fine.times = 1;
                    this.profile.newrecord.fines.push(fine);
                }

                this.profile.newrecord.maxFine += fine.value;
                this.profile.newrecord.maxPrison += fine.prison;
            },

            makeNewRecord() {
                let maxFine = this.profile.newrecord.maxFine;
                let maxPrison = this.profile.newrecord.maxPrison;

                if (maxFine <= 0 || maxPrison < 0) {
                    return;
                }

                let fineAmount = Number(this.profile.newrecord.fine);
                if (fineAmount > maxFine || fineAmount <= 0) {
                    showAlert('Maksimaalne rahaline trahv on ' + maxFine + '€.', 'error');
                    return false;
                }

                let prisonTime = Number(this.profile.newrecord.prison);
                if (prisonTime > maxPrison || prisonTime < 0) {
                    showAlert('Maksimaalne vangla karistus on ' + maxPrison + ' kuud.', 'error');
                    return false;
                }

                $.post(`https://${GetParentResourceName()}/newrecord`, JSON.stringify({
                    desc: this.profile.newrecord.desc,
                    identifier: this.profile.identifier,
                    fine: fineAmount,
                    prison: prisonTime,
                    fines: this.profile.newrecord.fines,
                }), (success) => {
                    if (!success) {
                        showAlert('Serveri viga.', 'error');
                        return;
                    }

                    this.profile_page = 'warrant';
                    this.profile.newrecord = {
                        maxFine: 0,
                        maxPrison: 0,
                        desc: '',
                        search: '',
                        fines: [],

                        prison: 0,
                        fine: 0,
                    };

                    if (this.fines.length > 0) {
                        for (let i = 0; i < this.fines.length; i++) {
                            this.fines[i].times = 0;
                        }
                    } else {
                        console.log('Error no fines.')
                    }

                    showAlert('Süüdistus on esitatud.', 'success');
                });

                return true;
            },

            removeFine(fineIdx) {
                let Fines = this.fines;
                let fine = Fines[fineIdx];

                if (fine.times <= 0) return this.profile.newrecord.fines.splice(fineIdx, 1);

                fine.times -= 1;

                this.profile.newrecord.maxFine -= fine.value;
                this.profile.newrecord.maxPrison -= fine.prison;
            },

            canShowPage(page) {
                return this.page === page && !this.loading;
            },

            showMoreRecord(record) {
                record.extra_content = !record.extra_content;
            },

            openProfile(identifier) {
                this.loading = true;

                $.post(`https://${GetParentResourceName()}/profile`, JSON.stringify({ identifier: identifier }), (data) => {
                    this.profile = data;

                    this.profile.newrecord = {
                        maxFine: 0,
                        maxPrison: 0,
                        desc: '',
                        search: '',

                        prison: 0,
                        fine: 0,
                        fines: [],
                    }

                    this.profile.assets = [];

                    for (let i = 0; i < this.fines.length; i++) {
                        this.fines[i].times = 0;
                    }

                    this.profile.notes = String(data.notes);

                    this.profile_page = 'warrant';
                    this.page = 'profile';
                    this.loading = false;
                });
            },

            changeProfilePage(page) {
                if (page == this.profile_page) {
                    return this.profile_page = 'warrant';
                }

                if (page == 'records') {
                    this.profile_page = 'loading';

                    $.post(`https://${GetParentResourceName()}/records`, JSON.stringify({ identifier: this.profile.identifier }), (data) => {
                        this.profile.records = data;
                        for (let i = 0; i < data.length; i++) {
                            for (let j = 0; j < data[i].fines.length; j++) {
                                let fine = data[i].fines[j];

                                if (!this.profile.records[i].labels) {
                                    this.profile.records[i].labels = [];
                                }

                                this.profile.records[i].labels[j] = `${fine.times} x ${fine.label}\n`;
                            }
                        }

                        this.profile_page = 'records';
                    });
                } else if (page == 'assets') {
                    this.profile_page = 'loading'; this.profile.assets = [];

                    $.post(`https://${GetParentResourceName()}/assets`, JSON.stringify({ identifier: this.profile.identifier }), (data) => {
                        this.profile.assets = data;
                        this.profile_page = 'assets';
                    });
                } else if (page == 'licenses') {
                    this.profile_page = 'licenses';
                } else if (page == 'search_fines') {
                    this.profile_page = 'search_fines';
                } else if (page == 'fine') {
                    this.profile_page = 'fine';
                }
            },

            clearProfileData() {
                this.profile = {
                    assets: [], records: [], newrecord: {
                        maxFine: 0,
                        maxPrison: 0,
                        desc: '',
                        search: '',

                        prison: 0,
                        fine: 0,
                        fines: [],
                    }
                };
            },

            displayLicense(type) {
                if (type == 'car') {
                    return `<span style="color: ${this.profile.veh_license ? 'green' : 'red'}"> ${this.profile.veh_license ? 'Valid' : 'Invalid'}</span>`
                } else {
                    return `<span style="color: ${this.profile.gun_license ? 'green' : 'red'}"> ${this.profile.gun_license ? 'Valid' : 'Invalid'}</span>`
                }
            },

            saveNotes() {
                $('.notes-button').attr('disabled', true);

                $('.notes-button').html(`<span
                    class="spinner-border spinner-border-sm" role="status"
                    aria-hidden="true"></span>
                    Salvestan...`
                );

                let notes = $('#notes').val(); if (notes.length <= 0) return; this.profile.notes = String(notes);
                $.post(`https://${GetParentResourceName()}/saveNotes`, JSON.stringify({ notes: notes, identifier: this.profile.identifier }), (success) => {
                    if (!success) {
                        $('.notes-button').removeClass('btn-success').addClass('btn-danger');
                        $('.notes-button').html(`<i class="fa-solid fa-xmark"></i> Märkmete salvestamine ebaõnnestus.`);
                        setTimeout(() => {
                            $('.notes-button').text(`Save`).removeClass('btn-danger').addClass('btn-success');
                        }, 1500);

                        $('.notes-button').attr('disabled', false);
                    };

                    $('.notes-button').html(`<i class="fa-solid fa-check"></i> Salvestatud.`);
                    setTimeout(() => {
                        $('.notes-button').text(`Save`);
                    }, 1500);
                });
            },

            removeLicense(license) {
                $.post(`https://${GetParentResourceName()}/removeLicense`, JSON.stringify({ license: license, identifier: this.profile.identifier }), (success) => {
                    if (!success) return showAlert('Lube ei saanud eemaldada.', 'error');

                    if (license == 'drive') {
                        this.profile.veh_license = false;
                    } else if (license == 'weapon') {
                        this.profile.gun_license = false;
                    }
                });
            },

            deleteWarrant() {
                this.loading = true;

                $.post(`https://${GetParentResourceName()}/deleteWarrant`, JSON.stringify({ id: this.selectedWarrant.id }), (success) => {
                    if (!success) return showAlert('Warrant couldn`t be removed.', 'error');

                    for (let i = 0; i < this.warrants.length; i++) {
                        if (this.warrants[i].id == this.selectedWarrant.id) {
                            this.warrants.splice(i, 1);
                            break;
                        }
                    }

                    this.selectedWarrant = [];

                    this.loading = false; this.page = 'warrants';
                });
            },

            addWarrant() {
                if (this.profile.warrant) {
                    return showAlert('Player already has a warrant.', 'error');
                }

                this.profile_page = 'loading';

                var warrantText = $('#warrant-desc').val();
                var date = new Date();
                date.setDate(date.getDate() + 7);

                $.post(`https://${GetParentResourceName()}/addWarrant`, JSON.stringify({
                    identifier: this.profile.identifier,
                    name: this.profile.name,
                    description: warrantText,
                    expire: date
                }), (data) => {
                    if (!data.success) {
                        this.page = 'warrants';
                        return showAlert('Tagaotsitavust ei saanud lisada.', 'error');
                    }

                    this.warrants.push({
                        id: data.id,
                        identifier: this.profile.identifier,
                        name: this.profile.name,
                        description: warrantText,
                        expire: date,
                        author: data.author
                    });

                    this.page = 'warrants'; $('#warrant-desc').val('');
                });
            },

            getWarrants() {
                this.loading = true;
                this.page = 'warrants'
                $.post(`https://${GetParentResourceName()}/getWarrants`, JSON.stringify({}), (data) => {
                    this.warrants = data;
                    this.loading = false; this.page = 'warrants'
                });
            },

            getCalloutCoords(coords) {
                $.post(`https://${GetParentResourceName()}/getCalloutCoords`, JSON.stringify({ coords: coords }), (success) => {
                    if (success) return showAlert('Kaarti on uuendatud.', 'success');
                });
            },

            saveProfilePicture() {
                let img_url = this.profile.img;
                let isImage = /\.(jpg|jpeg|png|webp|avif|gif|svg)$/.test(img_url);

                if (img_url.length == 0) {

                } else if (!isImage) {
                    return showAlert('URL ei viita pildile!', 'error');
                }

                $.post(`https://${GetParentResourceName()}/saveProfilePicture`, JSON.stringify({ picture: img_url, identifier: this.profile.identifier }), (success) => {
                    if (success) return showAlert('Pilt on muudetud!', 'success');
                });
            }
        },

        computed: {
            getProfileMugshot() {
                if (this.profile.img && (this.profile.img.length > 0 && this.profile.img.indexOf('http') == 0 || this.profile.img.indexOf('https') == 0)) {
                    return this.profile.img;
                }

                return 'imgs/citizen.png';
            },

            hasWarrant() {
                return this.profile.warrant != undefined && this.profile.warrant != false;
            }
        }
    }).mount('#app')

    $(document).keyup((e) => {
        if (e.keyCode == 27) {
            $.post(`https://${GetParentResourceName()}/closeUI`, JSON.stringify({}), () => {
                App.show = false;
            })
        }
    });

    $('#notes').on('input', function () {
        if (App.profile.notes != $('#notes').val() && $('#notes').val().length > 0) {
            $('.notes-button').attr('disabled', false)
        } else {
            $('.notes-button').attr('disabled', true)
        }
    })

    var Alerts = [];
    function showAlert(message, type) {
        if (Alerts.length >= 3) {
            return;
        }

        let alertName = 'alert_' + (Alerts.length + 1);
        Alerts.push(alertName);

        let bgColor = 'bg-success';
        if (type == 'error') {
            bgColor = 'bg-danger';
        } else if (type == 'warning') {
            bgColor = 'bg-warning';
        }

        $('.toast-container').append(`
            <div id="${alertName}" class="toast my-1 align-items-center text-white ${bgColor} border-0" role="alert"
                aria-live="assertive" aria-atomic="true">
                <div class="d-flex">
                    <div class="toast-body">
                        ${message}
                    </div>
                    <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"
                        aria-label="Close"></button>
                </div>
            </div>
        `)

        let alertToast = document.getElementById(alertName);
        var toast = new bootstrap.Toast(alertToast);

        toast.show();
        alertToast.addEventListener('hidden.bs.toast', function () {
            Alerts.splice(Alerts.indexOf(alertName), 1); alertToast.remove()
        })

        if (App.show) { alertSound.play(); };
    }

    window.addEventListener('message', (e) => {
        switch (e.data.type) {
            case 'getFines':
                if (App.fines.length != 0) return;

                let fines = [];
                for (let i = 0; i < e.data.fines.length; i++) {
                    let fine = e.data.fines[i];

                    fines.push({
                        label: fine.label,
                        value: fine.value,
                        prison: fine.prison,
                        times: 0
                    });
                }

                App.fines = fines;

                break;
            case 'openUI':
                App.show = true; App.officerName = e.data.name;
                break;
            case 'addCallout':
                let callout = e.data.callout;
                App.callouts.push({
                    label: callout.label,
                    location: callout.location,
                    date: callout.date,
                    id: callout.id
                });

                if (App.callouts.length > 20) {
                    App.callouts.shift();
                }
                break;
        };
    });

    function WarrantTimer() {
        setInterval(function () {
            for (var key in App.warrants) {
                var warrant = App.warrants[key];
                var now = new Date().getTime();
                var expire = new Date(warrant.expire).getTime();
                var t = expire - now;

                if (t >= 0) {
                    var days = Math.floor(t / (1000 * 60 * 60 * 24));
                    var hours = Math.floor((t % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
                    var mins = Math.floor((t % (1000 * 60 * 60)) / (1000 * 60));
                    var secs = Math.floor((t % (1000 * 60)) / 1000);
                    warrant.expire_text = days + 'd ' + hours + 'h ' + mins + 'm ' + secs + 's';
                } else {
                    warrant.expire_text = 'EXPIRED';

                    $.post(`https://${GetParentResourceName()}/deleteWarrant`, JSON.stringify({
                        id: warrant.id
                    }), () => {
                        App.warrants.splice(App.warrants.indexOf(warrant), 1);
                    });
                }
            }
        }, 1000);
    }

    WarrantTimer();
});