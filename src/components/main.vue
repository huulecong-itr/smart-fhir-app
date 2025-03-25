<template>
  <div class="container">
    <div v-if="!isEmbedded" style="text-align: center">
      <h1>Smart on FHIR - Patients List</h1>
      <p><strong>Username:</strong> fhircamila</p>
      <p><strong>Password:</strong> epicepic1</p>
      <a
        class="btn btn-primary"
        v-if="!accesstoken"
        style="text-decoration: none"
        target="_blank"
        :href="authorizeLink"
      >
        Sign in
      </a>
      <hr />
    </div>

    <div v-if="loading" class="text-center">
      <div class="spinner-border text-primary" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
      <p>Loading patients data...</p>
    </div>

    <div v-if="error" class="alert alert-danger mt-3">
      {{ error }}
    </div>

    <div v-if="patients.length > 0" class="patients-table-container">
      <div class="d-flex justify-content-between mb-3">
        <h3>Patients ({{ bundle.total || patients.length }})</h3>
        <div v-if="!isEmbedded" class="search-box">
          <input 
            type="text" 
            class="form-control" 
            placeholder="Search patients..." 
            v-model="searchQuery"
          >
        </div>
      </div>

      <div class="table-responsive">
        <table class="table table-striped table-hover">
          <thead :class="isEmbedded ? 'table-light' : 'table-dark'">
            <tr>
              <th>ID</th>
              <th>Name</th>
              <th>Gender</th>
              <th>Birth Date</th>
              <th>Status</th>
              <th>Phone</th>
              <th>Address</th>
              <th v-if="!isEmbedded">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="patient in filteredPatients" :key="patient.id">
              <td>{{ patient.id }}</td>
              <td>
                <strong>{{ formatName(patient.name) }}</strong>
                <div v-if="patient.identifier" class="small text-muted">
                  {{ getIdentifier(patient.identifier, 'EPIC') }}
                </div>
              </td>
              <td>
                <span class="badge" :class="genderBadgeClass(patient.gender)">
                  {{ formatGender(patient.gender) }}
                </span>
              </td>
              <td>{{ formatDate(patient.birthDate) }}</td>
              <td>
                <span :class="patient.deceasedBoolean ? 'badge bg-danger' : 'badge bg-success'">
                  {{ patient.deceasedBoolean ? "Deceased" : "Active" }}
                </span>
              </td>
              <td>
                <div v-if="patient.telecom">
                  {{ getTelecom(patient.telecom, 'phone') }}
                </div>
              </td>
              <td>
                <div v-if="patient.address">
                  {{ formatAddress(patient.address) }}
                </div>
              </td>
              <td v-if="!isEmbedded">
                <button 
                  class="btn btn-sm btn-outline-primary"
                  @click="viewPatientDetails(patient)"
                >
                  Details
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Patient Details Modal (only for standalone) -->
      <div v-if="!isEmbedded" class="modal fade" id="patientDetailsModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-lg">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Patient Details</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body" v-if="selectedPatient">
              <PatientDetails :patient="selectedPatient" />
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from "axios";
import { Modal } from 'bootstrap';
import PatientDetails from './PatientDetails.vue';
import { Client } from 'fhirclient';

export default {
  components: {
    PatientDetails
  },
  data() {
    return {
      isEmbedded: false,
      code: "",
      accesstoken: "",
      loading: false,
      error: null,
      bundle: {},
      patients: [],
      selectedPatient: null,
      searchQuery: '',
      clientId: "d4ac39f0-4d2c-4247-b5c6-582d0adaa648",
      redirect: import.meta.env.PROD
        ? "https://lucid-wozniak-940eae.netlify.app"
        : "http://localhost:3000",
    };
  },
  computed: {
    authorizeLink() {
      return `https://fhir.epic.com/interconnect-fhir-oauth/oauth2/authorize?response_type=code&redirect_uri=${this.redirect}&client_id=${this.clientId}&state=1234&scope=patient.read,patient.search`;
    },
    filteredPatients() {
      if (!this.searchQuery) return this.patients;
      const query = this.searchQuery.toLowerCase();
      return this.patients.filter(patient => {
        const name = this.formatName(patient.name).toLowerCase();
        const id = patient.id.toLowerCase();
        const phone = this.getTelecom(patient.telecom, 'phone')?.toLowerCase() || '';
        const address = this.formatAddress(patient.address).toLowerCase();
        return name.includes(query) || 
               id.includes(query) || 
               phone.includes(query) || 
               address.includes(query);
      });
    }
  },
  methods: {
    async authenticateStandalone() {
      this.loading = true;
      this.error = null;
      try {
        const params = new URLSearchParams();
        params.append("grant_type", "authorization_code");
        params.append("redirect_uri", this.redirect);
        params.append("code", this.code);
        params.append("client_id", this.clientId);
        params.append("state", "1234");
        
        const config = {
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
        };
        
        const tokenResponse = await axios.post(
          "https://fhir.epic.com/interconnect-fhir-oauth/oauth2/token",
          params,
          config
        );
        
        this.accesstoken = tokenResponse.data.access_token;
        await this.fetchPatients();
      } catch (error) {
        console.error("Authentication failed:", error);
        this.error = "Failed to authenticate. Please try again.";
      } finally {
        this.loading = false;
      }
    },
    
    async authenticateEmbedded() {
      this.loading = true;
      this.error = null;
      try {
        const client = await Client.oauth2.ready();
        this.accesstoken = client.state.tokenResponse.access_token;
        await this.fetchPatients(client);
      } catch (error) {
        console.error("SMART launch failed:", error);
        this.error = "Failed to launch SMART app. Please try again.";
      } finally {
        this.loading = false;
      }
    },
    
    async fetchPatients(client = null) {
      try {
        let response;
        if (client) {
          // Use SMART client for embedded launch
          response = await client.request(`/Patient`);
        } else {
          // Use direct API call for standalone
          response = await axios.get(
            `https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Patient`,
            { headers: { Authorization: `Bearer ${this.accesstoken}` } }
          );
          response = response.data;
        }
        
        this.bundle = response;
    this.patients = response.entry
      ?.filter(entry => entry.resource?.resourceType === 'Patient')
      ?.map(item => item.resource) || [];
      } catch (error) {
        console.error("Failed to fetch patients:", error);
        this.error = "Failed to fetch patients. Please try again.";
      }
    },

    formatName(names) {
      if (!names || names.length === 0) return ;
      const name = names.find(n => n.use === 'official') || names[0];
      return name.text || `${name.given?.join(' ')} ${name.family}`;
    },

    formatGender(gender) {
      if (!gender) return ;
      return gender.charAt(0).toUpperCase() + gender.slice(1);
    },

    genderBadgeClass(gender) {
      switch(gender) {
        case 'male': return 'bg-info text-dark';
        case 'female': return 'bg-purple text-white';
        default: return 'bg-secondary text-white';
      }
    },

    formatDate(dateString) {
      if (!dateString) return ;
      return new Date(dateString).toLocaleDateString();
    },

    getTelecom(telecoms, system) {
      if (!telecoms) return null;
      const telecom = telecoms.find(t => t.system === system);
      return telecom?.value || null;
    },

    getIdentifier(identifiers, type) {
      if (!identifiers) return null;
      const identifier = identifiers.find(id => 
        id.type?.text === type || id.type?.coding?.[0]?.display === type
      );
      return identifier?.value || null;
    },

    formatAddress(addresses) {
      if (!addresses || addresses.length === 0) return ;
      const address = addresses.find(a => a.use === 'home') || addresses[0];
      return `${address.line?.join(', ') || ''}, ${address.city}, ${address.state}`;
    },

    viewPatientDetails(patient) {
      this.selectedPatient = patient;
      const modal = new Modal(document.getElementById('patientDetailsModal'));
      modal.show();
    },

    detectLaunchMode() {
      // Check if we're running inside Epic's SMART container
      if (window.parent !== window || window.location.href.includes('launch=')) {
        this.isEmbedded = true;
        this.authenticateEmbedded();
      } else {
        this.isEmbedded = false;
        this.code = this.$route.query.code;
        if (this.code) {
          this.authenticateStandalone();
        }
      }
    }
  },
  async mounted() {
    this.detectLaunchMode();
  }
};
</script>

<style scoped>
.patients-table-container {
  max-width: 1400px;
  margin: 0 auto;
}

.bg-purple {
  background-color: #6f42c1;
}

.search-box {
  width: 300px;
}

.table th {
  white-space: nowrap;
}

.badge {
  font-size: 0.8em;
  font-weight: 500;
  padding: 0.35em 0.65em;
}

.modal-body {
  padding: 20px;
}
</style>