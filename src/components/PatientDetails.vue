<template>
  <div class="patient-details">
    <div class="row">
      <div class="col-md-6">
        <table class="table table-sm table-borderless">
          <tbody>
            <tr>
              <th width="30%">Patient ID</th>
              <td>{{ patient.id }}</td>
            </tr>
            <tr>
              <th>Name</th>
              <td>{{ formatName(patient.name) }}</td>
            </tr>
            <tr>
              <th>Gender</th>
              <td>{{ formatGender(patient.gender) }}</td>
            </tr>
            <tr>
              <th>Birth Date</th>
              <td>{{ formatDate(patient.birthDate) }}</td>
            </tr>
            <tr>
              <th>Status</th>
              <td>
                <span :class="patient.deceasedBoolean ? 'badge bg-danger' : 'badge bg-success'">
                  {{ patient.deceasedBoolean ? "Deceased" : "Active" }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="col-md-6">
        <table class="table table-sm table-borderless">
          <tbody>
            <tr>
              <th width="30%">Marital Status</th>
              <td>{{ patient.maritalStatus?.text || 'Unknown' }}</td>
            </tr>
            <tr>
              <th>Language</th>
              <td>{{ formatLanguage(patient.communication) }}</td>
            </tr>
            <tr v-if="patient.generalPractitioner?.length > 0">
              <th>General Practitioner</th>
              <td>{{ patient.generalPractitioner[0].display }}</td>
            </tr>
            <tr v-if="patient.managingOrganization">
              <th>Organization</th>
              <td>{{ patient.managingOrganization.display }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="card mt-3">
      <div class="card-header bg-light">
        <h6 class="mb-0">Contact Information</h6>
      </div>
      <div class="card-body">
        <div class="row">
          <div class="col-md-6">
            <h6>Telecom</h6>
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Type</th>
                  <th>Value</th>
                  <th>Use</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="telecom in patient.telecom" :key="telecom.value">
                  <td>{{ telecom.system }}</td>
                  <td>{{ telecom.value }}</td>
                  <td>
                    <span class="badge" :class="getTelecomBadgeClass(telecom.use)">
                      {{ telecom.use }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="col-md-6">
            <h6>Addresses</h6>
            <div v-for="address in patient.address" :key="address.use" class="mb-3">
              <div class="card">
                <div class="card-header py-1 bg-light">
                  <strong>{{ address.use | capitalize }} Address</strong>
                  <span v-if="address.period?.start" class="float-end">
                    <small>Since {{ formatDate(address.period.start) }}</small>
                  </span>
                </div>
                <div class="card-body py-2">
                  <p class="mb-1">{{ address.line?.join(', ') }}</p>
                  <p class="mb-1">
                    {{ address.city }}, {{ address.state }} {{ address.postalCode }}
                  </p>
                  <p class="mb-0">{{ address.country }}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="card mt-3" v-if="patient.identifier?.length > 0">
      <div class="card-header bg-light">
        <h6 class="mb-0">Identifiers</h6>
      </div>
      <div class="card-body">
        <table class="table table-sm table-striped">
          <thead>
            <tr>
              <th>Type</th>
              <th>System</th>
              <th>Value</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="id in patient.identifier" :key="id.value">
              <td>{{ id.type?.text || 'Unknown' }}</td>
              <td><small>{{ id.system }}</small></td>
              <td>{{ id.value }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

  </div>
</template>

<script>
import axios from "axios";

export default {
  props: {
    patient: Object,
    fhirClient: Object,
    accessToken: String
  },
  data() {
    return {
      carePlans: [],
      loadingCarePlans: false,
      carePlansError: null
    };
  },
  filters: {
    capitalize(value) {
      if (!value) return '';
      value = value.toString();
      return value.charAt(0).toUpperCase() + value.slice(1);
    }
  },
  methods: {
    formatName(names) {
      if (!names || names.length === 0) return 'Unknown';
      const name = names.find(n => n.use === 'official') || names[0];
      return name.text || `${name.given?.join(' ')} ${name.family}`;
    },
    formatGender(gender) {
      if (!gender) return 'Unknown';
      return gender.charAt(0).toUpperCase() + gender.slice(1);
    },
    formatDate(dateString) {
      if (!dateString) return 'Unknown';
      return new Date(dateString).toLocaleDateString();
    },
    formatLanguage(communications) {
      if (!communications || communications.length === 0) return 'Unknown';
      return communications[0].language?.coding?.[0]?.display || 
             communications[0].language?.text || 'Unknown';
    },
    getTelecomBadgeClass(use) {
      switch (use) {
        case 'home': return 'bg-info text-dark';
        case 'work': return 'bg-warning text-dark';
        case 'mobile': return 'bg-success text-white';
        default: return 'bg-secondary text-white';
      }
    },
    carePlanStatusClass(carePlan) {
      switch(carePlan.status) {
        case 'active': return 'bg-success text-white';
        case 'completed': return 'bg-secondary text-white';
        case 'cancelled': return 'bg-danger text-white';
        default: return 'bg-warning text-dark';
      }
    },
    async fetchCarePlans() {
      this.loadingCarePlans = true;
      this.carePlansError = null;
      try {
        let response;
        if (this.fhirClient) {
          response = await this.fhirClient.request(`/CarePlan?patient=${this.patient.id}`);
        } else {
          response = await axios.get(
            `https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/CarePlan?patient=${this.patient.id}`,
            { headers: { Authorization: `Bearer ${this.accessToken}` } }
          );
          response = response.data;
        }
        
        this.carePlans = response.entry?.map(entry => entry.resource) || [];
      } catch (error) {
        console.error("Error fetching care plans:", error);
        this.carePlansError = "Failed to load care plans. Please try again.";
      } finally {
        this.loadingCarePlans = false;
      }
    }
  },
  mounted() {
    if (this.patient?.id) {
      this.fetchCarePlans();
    }
  },
  watch: {
    'patient.id'(newId) {
      if (newId) {
        this.fetchCarePlans();
      }
    }
  }
};
</script>

<style scoped>
.patient-details {
  font-size: 0.9rem;
}
.card-header {
  font-weight: 600;
}
.table th {
  font-weight: 500;
  color: #495057;
}
.badge {
  font-size: 0.75em;
  font-weight: 500;
  padding: 0.35em 0.65em;
}
</style>